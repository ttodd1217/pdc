resource "null_resource" "sftp_keypair" {
  triggers = {
    key_name    = var.sftp_key_name
    aws_region  = var.aws_region
    key_on_disk = tostring(fileexists("${path.module}/pdc-sftp-server-key.pem"))
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<-EOT
    try {
      $ErrorActionPreference = "Continue"

      $keyPath = Join-Path -Path "${path.module}" -ChildPath "pdc-sftp-server-key.pem"
      if (-not (Test-Path $keyPath)) {
        Write-Host "Generating ED25519 keypair at $keyPath"
        ssh-keygen -t ed25519 -f "$keyPath" -N "" -C "pdc-sftp-server"
      } else {
        Write-Host "Key already exists at $keyPath - skipping generation"
      }

      $pubPath = "$keyPath.pub"
      Write-Host "Importing public key to AWS as '${var.sftp_key_name}' (region ${var.aws_region})"

      aws ec2 import-key-pair `
        --key-name "${var.sftp_key_name}" `
        --region "${var.aws_region}" `
        --public-key-material fileb://$pubPath 2>&1 | Write-Host

      if ($LASTEXITCODE -ne 0) {
        Write-Host "Keypair already exists (or import failed). Ignoring so Terraform can continue."
        $global:LASTEXITCODE = 0
        exit 0
      }
    } catch {
      Write-Host "Warning: key generation/import failed: $_"
      $global:LASTEXITCODE = 0
      exit 0
    }
    EOT
  }
}
