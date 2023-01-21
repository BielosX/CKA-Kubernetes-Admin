resource "aws_vpc" "vpc" {
  cidr_block = var.cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = merge({
    Name: var.name
  }, var.tags)
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = length(var.availability-zones) > 0 ? var.availability-zones : data.aws_availability_zones.available.names
}

resource "aws_subnet" "pubic-subnet" {
  count = var.public-subnets
  vpc_id = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(var.cidr, ceil(log(var.subnet-size, 2)), count.index + 1)
  availability_zone = local.azs[count.index % length(local.azs)]
  tags = merge({
    Name: "${var.name}-public-subnet"
  }, var.tags, var.public-subnets-tags)
}

resource "aws_subnet" "private-subnet" {
  count = var.private-subnets
  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.cidr, ceil(log(var.subnet-size, 2)), var.public-subnets + count.index + 1)
  availability_zone = local.azs[count.index % length(local.azs)]
  tags = merge({
    Name: "${var.name}-private-subnet"
  }, var.tags, var.private-subnets-tags)
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = merge({
    Name: "${var.name}-internet-gateway"
  }, var.tags)
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    gateway_id = aws_internet_gateway.internet-gateway.id
    cidr_block = "0.0.0.0/0"
  }

  tags = merge({
    Name: "${var.name}-public-route-table"
  }, var.tags)
}

resource "aws_route_table_association" "public-route-table-association" {
  count = var.public-subnets
  route_table_id = aws_route_table.public-route-table.id
  subnet_id = aws_subnet.pubic-subnet[count.index].id
}

resource "aws_eip" "epi" {
  count = var.single-nat-gateway ? 1 : var.public-subnets
  vpc = true
  tags = merge({
    Name: "${var.name}-nat-gw-eip"
  }, var.tags)
}

resource "aws_nat_gateway" "nat-gateway" {
  count = var.single-nat-gateway ? 1 : var.public-subnets
  subnet_id = aws_subnet.pubic-subnet[count.index].id
  allocation_id = aws_eip.epi[count.index].id

  tags = merge({
    Name: "${var.name}-nat-gateway"
  }, var.tags)
}

resource "aws_route_table" "private-route-table" {
  count = var.single-nat-gateway ? 1 : var.public-subnets
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway[count.index].id
  }

  tags = merge({
    Name: "${var.name}-private-route-table"
  }, var.tags)
}

resource "aws_route_table_association" "private-route-table-association" {
  count = var.private-subnets
  route_table_id = (var.single-nat-gateway ?
    (aws_route_table.private-route-table[0].id) :
    (aws_route_table.private-route-table[count.index % var.public-subnets].id))
  subnet_id = aws_subnet.private-subnet[count.index].id
}