output "arn" {
  description = "Amazon Resource Name (ARN) of the domain"
  value       = "${element(concat(aws_elasticsearch_domain.es.*.arn, list("")), 0)}"
}

output "domain_id" {
  description = "Unique identifier for the domain"
  value       = "${element(concat(aws_elasticsearch_domain.es.*.domain_id, list("")), 0)}"
}

output "domain_name" {
  description = "The name of the Elasticsearch domain"
  value       = "${element(concat(aws_elasticsearch_domain.es.*.domain_name, list("")), 0)}"
}

output "endpoint" {
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
  value       = "${element(concat(aws_elasticsearch_domain.es.*.endpoint, list("")), 0)}"
}

output "kibana_endpoint" {
  description = "Domain-specific endpoint for kibana without https scheme"
  value       = "${element(concat(aws_elasticsearch_domain.es.*.kibana_endpoint, list("")), 0)}"
}