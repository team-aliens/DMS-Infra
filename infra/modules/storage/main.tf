resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DB 백업 등 prefix 하위 객체의 자동 만료 (비용 관리)
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count  = var.backup_prefix != "" && var.backup_retention_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-${var.backup_prefix}"
    status = "Enabled"

    filter {
      prefix = "${var.backup_prefix}/"
    }

    expiration {
      days = var.backup_retention_days
    }

    # 버저닝 켜진 버킷에서 과거 버전도 같이 정리
    noncurrent_version_expiration {
      noncurrent_days = var.backup_retention_days
    }

    # 스트리밍 업로드 중 끊긴 멀티파트 잔여물 정리
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
