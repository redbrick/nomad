client {
  enabled = true
  # for minecraft modpack zip bombing allowance
  artifact {
    decompression_size_limit       = "0"
    decompression_file_count_limit = 12000
  }
  bridge_network_hairpin_mode = true
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}
