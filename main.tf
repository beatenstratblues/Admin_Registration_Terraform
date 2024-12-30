resource "aws_vpc" "private-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    name = "Private-VPC"
  }
}

resource "aws_vpc" "public-vpc" {
  cidr_block           = "11.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    name = "Public-VPC"
  }
}

resource "aws_vpc_peering_connection" "peer_connection" {
  vpc_id      = aws_vpc.public-vpc.id
  peer_vpc_id = aws_vpc.private-vpc.id

  tags = {
    Name = "public-to-private-peering"
  }
}

resource "aws_vpc_peering_connection_accepter" "peer_connection_accepter" {
  vpc_peering_connection_id = aws_vpc_peering_connection.peer_connection.id
  auto_accept               = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.public-vpc.id

  tags = {
    Name = "Public-VPC-internet-gateway"
  }
}

resource "aws_route_table" "internet-route-table" {
  vpc_id = aws_vpc.public-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  route {
    cidr_block                = aws_vpc.private-vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer_connection.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table" "private-internet-route-table" {
  vpc_id = aws_vpc.private-vpc.id

  route {
    cidr_block                = aws_vpc.public-vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer_connection.id
  }
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.private-internet-route-table.id
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.internet-route-table.id
}

resource "aws_subnet" "private-subnet-1" {
  vpc_id            = aws_vpc.private-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private-subnet-under-private-vpc"
  }
}

resource "aws_subnet" "private-subnet-2" {
  vpc_id            = aws_vpc.private-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private-subnet-under-private-vpc"
  }
}

resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = aws_vpc.public-vpc.id
  cidr_block              = "11.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"

  tags = {
    Name = "public-subnet-under-public-vpc"
  }
}

resource "aws_db_subnet_group" "private-subnet-group" {
  name = "private-db-subnet-group"
  subnet_ids = [
    aws_subnet.private-subnet-1.id,
    aws_subnet.private-subnet-2.id
  ]

  tags = {
    Name = "private-db-subnet-group"
  }
}


resource "aws_db_instance" "dbs-instance" {
  allocated_storage    = 20
  db_name              = "Admin_Registration"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t4g.micro"
  username             = "root"
  password             = "rootpassword"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.private-subnet-group.name
}


resource "aws_security_group" "public-vpc-sg" {
  name        = "public-sg"
  description = "public-security-group"
  vpc_id      = aws_vpc.public-vpc.id

  ingress = [{
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Allow all inbound traffic"
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]

  egress = [{
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Allow all outbound traffic"
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]
}


# resource "aws_security_group" "private-vpc-sg" {
#   name        = "private-sg"
#   description = "private-security-group"
#   vpc_id      = aws_vpc.private-vpc.id

#   ingress = [{
#     from_port        = 8
#     to_port          = -1
#     protocol         = "icmp"
#     cidr_blocks      = ["11.0.0.0/16"]
#     description      = "Allow all inbound traffic"
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     security_groups  = []
#     self             = false
#   }]

#   egress = [{
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "Allow all outbound traffic"
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     security_groups  = []
#     self             = false
#   }]
# }

resource "aws_key_pair" "ec2_auth" {
  key_name   = "mtckey"
  public_key = file("~/.ssh/mtckey.pub")
}
data "aws_ami" "aws-linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-2023.6.*.0-kernel-6.1-x86_64"]
  }
  owners = ["137112412989"]
}

resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ec2_auth.id
  vpc_security_group_ids = [aws_security_group.public-vpc-sg.id]
  subnet_id              = aws_subnet.public-subnet-1.id

  user_data = file("./ec2-user-data.sh")

  root_block_device {
    volume_size = 8
  }

  tags = {
    Name = "test-node"
  }

}
# resource "aws_instance" "ec2_instance-private" {
#   ami                    = data.aws_ami.aws-linux.id
#   instance_type          = "t2.micro"
#   key_name               = aws_key_pair.ec2_auth.id
#   vpc_security_group_ids = [aws_security_group.private-vpc-sg.id]
#   subnet_id              = aws_subnet.private-subnet-1.id

#   user_data = file("./ec2-user-data.sh")

#   root_block_device {
#     volume_size = 8
#   }

#   tags = {
#     Name = "test-node"
#   }

# }

