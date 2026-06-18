data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ECR pull (CD가 푸시한 이미지를 docker pull)
resource "aws_iam_role_policy_attachment" "ecr_read" {
  count = var.enable_ecr_read ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

data "aws_iam_policy_document" "s3" {
  count = var.enable_s3 ? 1 : 0

  statement {
    sid       = "BucketLevel"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [var.s3_bucket_arn]

    dynamic "condition" {
      for_each = var.s3_prefix == null ? [] : [var.s3_prefix]
      content {
        test     = "StringLike"
        variable = "s3:prefix"
        values   = ["${condition.value}/*"]
      }
    }
  }

  statement {
    sid = "ObjectLevel"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [var.s3_prefix == null ? "${var.s3_bucket_arn}/*" : "${var.s3_bucket_arn}/${var.s3_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "s3" {
  count = var.enable_s3 ? 1 : 0

  name   = "${var.name}-s3"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.s3[0].json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-profile"
  role = aws_iam_role.this.name
  tags = var.tags
}
