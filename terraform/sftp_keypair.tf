# Use existing public key from pdc-sftp-server-key.pub
resource "aws_key_pair" "sftp" {
  key_name   = var.sftp_key_name
  public_key = file("${path.module}/pdc-sftp-server-key.pub")
}
