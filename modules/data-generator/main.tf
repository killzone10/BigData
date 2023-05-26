locals {

}
resource "random_integer" "random_length" {
  min = 100
  max = 5000
}

resource "random_string" "random_string" {
  length           = random_integer.random_length.result
  special          = true
  override_special = ","
  min_special      = 100

}

locals {
  input_list   = compact([for s in split(",", random_string.random_string.result) : s])
  input_length = length(local.input_list)
  file_content = format("%s%s", trimprefix(join("\n", local.input_list), "\n"), "\n")
}

resource "local_file" "input_data" {
  content  = local.file_content
  filename = "data/input.csv"
}
