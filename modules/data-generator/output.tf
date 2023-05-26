output "lines_number" {
  value       = local.input_length
  description = "Number of lines in a generated file"
}

output "file_path" {
  value       = local_file.input_data.filename
  description = "File path"
}