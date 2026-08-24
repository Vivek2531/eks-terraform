output "vpc_id" {
    value = aws_vpc.k8s-vpc.id
  
}
output "cluster_id" {
    value = aws_eks_cluster.sample_cluster.id
    
}

output "node_group_id" {
    value = aws_eks_node_group.sample_node_group.id
  
}

output "subnet_id" {    
    value = aws_subnet.pub_subent1[*].id
}

output "cluster_endpoint" {
    value = aws_eks_cluster.sample_cluster.endpoint
  
}