provider "aws" {
    region = "us-east-1"
    access_key = ""
    secret_key = ""
}

resource "aws_vpc" "my-vpc" {

    cidr_block = "10.0.0.0/16"
        tags = {
          "Name" = "development"
        }
  
}


resource "aws_internet_gateway" "gw" {

    vpc_id = aws_vpc.my-vpc.id
  
}


resource "aws_route_table" "dev-route-table" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "dev"
  }
}


resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.my-vpc.id
    cidr_block = "10.0.0.0/16"
    availability_zone = "us-east-1a"

    tags = {
      "Name" = "dev-subnet"
    }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.dev-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description      = "HTTP"
    from_port        = 80   
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
   
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
   
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
} 


resource "aws_network_interface" "web-server-dragons" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.8"]
  security_groups = [aws_security_group.allow_web.id]

}

resource "aws_eip" "one" {

    vpc = true
    network_interface = aws_network_interface.web-server-dragons.id
    associate_with_private_ip = "10.0.1.8"
    depends_on = [
      aws_internet_gateway.gw
    ]
  
}

resource "aws_instance" "web-server-instance" {
    ami = "ami-052efd3df9dad4825"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "main-key"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web-server-dragons.id
    }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'Hello World! > /var/www/html/index.html'
                EOF

    tags = {
      "Name" = "web-server"
    }
    
                                
}