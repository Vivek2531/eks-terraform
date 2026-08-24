provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "k8s-vpc" {
    cidr_block = "10.0.0.0/16"
  
}

resource "aws_subnet" "pub_subent1" {
    count = 2
    vpc_id = aws_vpc.k8s-vpc.id
    cidr_block = cidrsubnet(aws_vpc.k8s-vpc.cidr_block,8,count.index)
    availability_zone = element(["us-east-1a","us-east-1b"],count.index)
    map_public_ip_on_launch = true
    tags = {
        Name = "pub-sub-${count.index}"
    }
  
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s-vpc.id
  tags = {
    Name = "igw-data"
  }
}

resource "aws_route_table" "k8s" {
    vpc_id = aws_vpc.k8s-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "k8s-rt"
    }
  
}

resource "aws_route_table_association" "pub-subents" {
    count = 2
    subnet_id = aws_subnet.pub_subent1[count.index].id
    route_table_id = aws_route_table.k8s.id

}

resource "aws_security_group" "cluster-sg" {
    vpc_id = aws_vpc.k8s-vpc.id
    name = "cluster-sg"

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}

resource "aws_security_group" "nodes-sg" {
    vpc_id = aws_vpc.k8s-vpc.id
    name = "nodes-sg"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}


resource "aws_eks_cluster" "sample_cluster" {
    name = "first-cluster"
    role_arn = aws_iam_role.eks-cluster-role.arn

    vpc_config {
      subnet_ids = aws_subnet.pub_subent1[*].id
      security_group_ids = [aws_security_group.cluster-sg.id]
    }

    depends_on = [ aws_iam_role_policy_attachment.eks-cluster-role-attachemnt ]

}

resource "aws_eks_node_group" "sample_node_group" {
  cluster_name = aws_eks_cluster.sample_cluster.name
  node_group_name = "sample-node-group"
  node_role_arn = aws_iam_role.eks-node-group-role.arn
  subnet_ids = aws_subnet.pub_subent1[*].id
  scaling_config {
    desired_size = 2
    max_size = 3
    min_size = 1
  }
  instance_types = ["t3.medium"]
  remote_access {
    ec2_ssh_key = var.ssh-ec2_ssh_key
    source_security_group_ids = [aws_security_group.nodes-sg.id]

  }
  tags = {
    Name = "sample-node-group"
  }
}

resource "aws_iam_role" "eks-cluster-role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks-cluster-role-attachemnt" {
    role = aws_iam_role.eks-cluster-role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks-node-group-role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks-node-group-role-attachemnt" {
    role = aws_iam_role.eks-node-group-role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    
}

resource "aws_iam_role_policy_attachment" "eks-node-group-cni-policy" {
    role = aws_iam_role.eks-node-group-role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "els-node-group-registry-read-only" {
    role = aws_iam_role.eks-node-group-role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  
}