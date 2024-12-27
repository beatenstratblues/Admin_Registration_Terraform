resource "aws_vpc" "private-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    name = "Private-VPC"
  }
}

resource "aws_vpc" "public-vpc" {
  cidr_block = "11.0.0.0/16"

  tags = {
    name = "Public-VPC"
  }
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

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.internet-route-table.id
}

resource "aws_subnet" "private-subnet-1" {
  vpc_id     = aws_vpc.private-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private-subnet-under-private-vpc"
  }
}

resource "aws_subnet" "private-subnet-2" {
  vpc_id     = aws_vpc.private-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private-subnet-under-private-vpc"
  }
}

resource "aws_subnet" "public-subnet-1" {
  vpc_id     = aws_vpc.public-vpc.id
  cidr_block = "11.0.0.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public-subnet-under-public-vpc"
  }
}


resource "aws_db_subnet_group" "private-subnet-group" {
  name       = "private-db-subnet-group"
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