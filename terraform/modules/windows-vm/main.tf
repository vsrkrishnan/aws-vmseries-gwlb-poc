###################################
## Virtual Machine Module - Main ##
###################################

# Get latest Windows Server 2022 AMI
data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base*"]
  }
}

# Bootstrapping PowerShell Script
data "template_file" "windows-userdata" {
  template = <<EOF
<powershell>
# Rename Machine
Rename-Computer -NewName "${var.windows_instance_name}" -Force;

# Install IIS
Install-WindowsFeature -name Web-Server -IncludeManagementTools;

# Restart machine
shutdown -r -t 10;
</powershell>
EOF
}

# Create EC2 Instance
resource "aws_instance" "windows-server" {
  ami                         = data.aws_ami.windows.id
  instance_type               = var.windows_instance_type
  subnet_id                   = var.windows-subnet-id
  vpc_security_group_ids      = [var.windows-sg-id]
  associate_public_ip_address = var.windows_associate_public_ip_address
  source_dest_check           = false
  key_name                    = var.ssh_key_name
  user_data                   = data.template_file.windows-userdata.rendered
  
  # root disk
  root_block_device {
    volume_size           = var.windows_root_volume_size
    volume_type           = var.windows_root_volume_type
    delete_on_termination = true
    encrypted             = true
  }

  # extra disk
  ebs_block_device {
    device_name           = "/dev/xvda"
    volume_size           = var.windows_data_volume_size
    volume_type           = var.windows_data_volume_type
    encrypted             = true
    delete_on_termination = true
  }
  
  tags = merge({ Name = "${var.prefix-name-tag}${var.windows_instance_name}" }, var.global_tags)
}

# Create Elastic IP for the EC2 instance
resource "aws_eip" "windows-eip" {
  # vpc  = true
  tags = merge({ Name = "${var.prefix-name-tag}windows-eip" }, var.global_tags)
}

# Associate Elastic IP to Windows Server
resource "aws_eip_association" "windows-eip-association" {
  instance_id   = aws_instance.windows-server.id
  allocation_id = aws_eip.windows-eip.id
}