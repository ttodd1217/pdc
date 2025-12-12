/* Replaced the platform-specific local-exec provisioner with a cross-platform,
   Terraform-managed keypair using the tls provider. This produces an ED25519
   private key, registers the public key with EC2, and writes the private key
   to a local file. Note: the private key will be included in Terraform state
   (sensitive). Protect your state backend accordingly. */

resource "tls_private_key" "sftp" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "sftp" {
  key_name   = var.sftp_key_name
  public_key = tls_private_key.sftp.public_key_openssh
}

resource "local_file" "sftp_private_key" {
  content         = tls_private_key.sftp.private_key_pem
  filename        = "${path.module}/pdc-sftp-server-key.pem"
  file_permission = "0600"
  sensitive       = true
}
