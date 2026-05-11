locals {
  mime_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    svg  = "image/svg+xml"
  }
}

resource "aws_s3_object" "frontend_files" {
  for_each = fileset("${path.module}/../src/frontend", "**/*")

  bucket       = aws_s3_bucket.frontend.id
  key          = each.value
  source       = "${path.module}/../src/frontend/${each.value}"
  
  # Automatically set the correct Content-Type based on the file extension
  content_type = lookup(local.mime_types, regex("[^.]+$", each.value), "binary/octet-stream")
  
  # This tells Terraform to update the object if the file contents change locally
  source_hash  = filemd5("${path.module}/../src/frontend/${each.value}")
}

# Invalidate the CloudFront cache whenever any frontend file changes
resource "null_resource" "invalidate_cloudfront" {
  triggers = {
    files_hash = sha1(join("", [for f in fileset("${path.module}/../src/frontend", "**/*") : filemd5("${path.module}/../src/frontend/${f}")]))
  }

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend_cf.id} --paths \"/*\""
  }

  depends_on = [aws_s3_object.frontend_files]
}
