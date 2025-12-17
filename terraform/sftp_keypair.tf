# Use existing public key - hardcoded
resource "aws_key_pair" "sftp" {
  key_name   = "pdc-sftp-server-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRmkF13Mwt/iq+RecnzBgdRkkFYw7QJGOYAD24BfLNz administrator@DESKTOP-4517OPL"
}
