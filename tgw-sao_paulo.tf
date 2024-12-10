
variable "regions_SP" {
  default = ["sao_paulo"] 
}

variable "hub_region_SP" {
  default = "tokyo" 
}

#############################################################
# TRANSIT GATEWAY - sao_paulo
#############################################################
resource "aws_ec2_transit_gateway" "local_sao_paulo" {
  provider = aws.sao_paulo 
  description = "sao_paulo" 
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support = "enable"
  tags = {
    Name = "sao_paulo TGW" 
  }
}
#############################################################
# TRANSIT GATEWAY VPC ATTACHMENT
#############################################################
resource "aws_ec2_transit_gateway_vpc_attachment" "local_sao_paulo_attachment" {
  provider = aws.sao_paulo
  subnet_ids         = aws_subnet.private_subnet_SaoPaulo[*].id 
  transit_gateway_id = aws_ec2_transit_gateway.local_sao_paulo.id
  vpc_id             = aws_vpc.saopaulo.id 
  dns_support        = "enable"
  tags = {
    Name = "Attachment for tokyo" 
  }
}
#############################################################
# TRANSIT GATEWAY PEERING ATTACHMENT
#############################################################
resource "aws_ec2_transit_gateway_peering_attachment" "hub_to_spoke_sao_paulo" {
  transit_gateway_id      = aws_ec2_transit_gateway.local_sao_paulo.id 
  peer_transit_gateway_id = aws_ec2_transit_gateway.peer.id 
  peer_region             = "ap-northeast-1" 
  tags = {
    Name = "Hub to Spoke Peering new york" 
  }
  provider = aws.sao_paulo 
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "spoke_accept_tko_sao_paulo" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.hub_to_spoke_sao_paulo.id
  provider                      = aws.tokyo 
  tags = {
    Name = "Spoke Accept Hub Peering tokyo"
  }
}
#############################################################
# TRANSIT GATEWAY ROUTE TABLE ASSOCIATIONS
#############################################################

# Associate Hub TGW Route Table with Tokyo VPC Attachment
resource "aws_ec2_transit_gateway_route_table_association" "hub_tgw_vpc" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.peer_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub_route_table.id
  provider = aws.tokyo
}

# Associate Spoke TGW Route Table with New York VPC Attachment
resource "aws_ec2_transit_gateway_route_table_association" "spoke_tgw_vpc" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.local_new_york_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_route_table.id
  provider = aws.new_york
}
# Associate Spoke TGW Route Table with New York perring Attachment
resource "aws_ec2_transit_gateway_route_table_association" "tgw_attachment_association" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.hub_to_spoke.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_route_table.id

  provider = aws.new_york

}
# Associate Hub TGW Route Table with Tokyo Peering Attachment
resource "aws_ec2_transit_gateway_route_table_association" "tgw_attachment_association_peer" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.hub_to_spoke.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub_route_table.id

  provider = aws.tokyo

}

#############################################################
# TRANSIT GATEWAY ROUTE TABLE CONFIGURATION
#############################################################

resource "aws_ec2_transit_gateway_route_table" "hub_route_table_tko_sao_paulo" {
  transit_gateway_id = aws_ec2_transit_gateway.peer.id 
  tags = {
    Name = "Hub TGW Route Table (Tokyo)"
  }
  provider = aws.tokyo 
}

resource "aws_ec2_transit_gateway_route_table" "spoke_route_table_sao_paulo" {
  transit_gateway_id = aws_ec2_transit_gateway.local_sao_paulo.id 
  tags = {
    Name = "Spoke TGW Route Table (sao_paulo)" 
  }
  provider = aws.sao_paulo 
}
#############################################################
# TRANSIT GATEWAY ROUTE TABLE ASSOCIATIONS
#############################################################

# Associate Hub TGW Route Table with Tokyo VPC Attachment
resource "aws_ec2_transit_gateway_route_table_association" "hub_tgw_vpc_sao_paulo" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.peer_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub_route_table_tko_sao_paulo.id
  provider = aws.tokyo
}

# Associate Spoke TGW Route Table with New York VPC Attachment
resource "aws_ec2_transit_gateway_route_table_association" "spoke_tgw_vpc_sao_paulo" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.local_sao_paulo_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_route_table_sao_paulo.id
  provider = aws.sao_paulo
}
# Associate Spoke TGW Route Table with New York perring Attachment
resource "aws_ec2_transit_gateway_route_table_association" "tgw_attachment_association_sao_paulo" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.hub_to_spoke_sao_paulo.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_route_table_sao_paulo.id

  provider = aws.sao_paulo

}
# Associate Hub TGW Route Table with Tokyo Peering Attachment
resource "aws_ec2_transit_gateway_route_table_association" "tgw_attachment_association_peer_sao_paulo" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.hub_to_spoke_sao_paulo.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub_to_spoke_tko_sao_paulo.id

  provider = aws.tokyo

}

#############################################################
# TRANSIT GATEWAY ROUTES
#############################################################

resource "aws_ec2_transit_gateway_route" "hub_to_spoke_tko_sao_paulo" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub_route_table_tko_sao_paulo.id
  destination_cidr_block         = aws_vpc.saopaulo.cidr_block 
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.hub_to_spoke_sao_paulo.id
  provider                       = aws.tokyo 
}

resource "aws_ec2_transit_gateway_route" "hub_to_hub_vpc_tko_sao_paulo" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub_route_table_tko_sao_paulo.id
  destination_cidr_block         = aws_vpc.tokyo.cidr_block 
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.peer_attachment.id
  provider                       = aws.tokyo 
}

resource "aws_ec2_transit_gateway_route" "spoke_to_hub_sao_paulo" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_route_table_sao_paulo.id
  destination_cidr_block         = aws_vpc.tokyo.cidr_block 
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.hub_to_spoke_sao_paulo.id
  provider                       = aws.sao_paulo 
}

resource "aws_ec2_transit_gateway_route" "spoke_to_spoke_vpc_sao_paulo" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_route_table_sao_paulo.id
  destination_cidr_block         = aws_vpc.saopaulo.cidr_block 
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.local_sao_paulo_attachment.id
  provider                       = aws.sao_paulo 
}

#############################################################
# VPC ROUTE TABLE CONFIGURATION
#############################################################
resource "aws_route" "spoke_to_hub_sao_paulo" {
  route_table_id         = aws_route_table.saoaws_sao_paulo_route_table_private_subnet.id 
  destination_cidr_block = aws_vpc.tokyo.cidr_block 
  transit_gateway_id     = aws_ec2_transit_gateway.local_sao_paulo.id
  provider               = aws.sao_paulo 
}