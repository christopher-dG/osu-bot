import json
import os
import tempfile
import time
import traceback

from pathlib import PosixPath
from typing import Any, Dict, Optional, Union

import boto3

from botocore.exceptions import ClientError

_bucket = boto3.resource("s3").Bucket(os.getenv("S3_BUCKET", ""))
_lambda = boto3.client("lambda")
_lambda_prefix = os.getenv("LAMBDA_PREFIX", "")
_table = boto3.resource("dynamodb").Table(os.getenv("DYNAMODB_TABLE", ""))


def ddb_get_item(key: str) -> Optional[Dict[str, Union[int, str]]]:
    """Get an item from DynamoDB."""
    resp = _table.get_item(Key={"id": {"S": key}})
    if "Item" not in resp:
        return None
    item = resp["Item"]
    for k, v in item.items():
        vtype = list(v.keys())[0]
        if vtype == "N":
            item[k] = int(v)
        else:
            item[k] = v
    return item


def ddb_put_item(key: str, item: Dict[str, Union[int, str]]) -> None:
    """Put an item into DynamoDB."""
    item["ttl"] = round(time.time())
    _table.put_item(
        Item={k: {"N" if isinstance(v, int) else "S": str(v)} for k, v in item.items()}
    )


def s3_get_object(key: str) -> Optional[str]:
    """Download a file from S3 and return the path on disk."""
    _, dest = tempfile.mkstemp()
    try:
        _bucket.download_file(key, dest)
    except ClientError:
        traceback.print_exc()
        return None
    return dest


def s3_put_object(key: str, file: PosixPath) -> None:
    """Upload a file to S3."""
    with open(file) as f:
        _bucket.put_object(Body=f)


def lambda_invoke_function(function: str, payload: Dict[str, Any]) -> None:
    """Invoke a Lambda function."""
    _lambda.invoke(
        FunctionName=_lambda_prefix + function,
        Payload=json.dumps(payload),
        InvocationType="Event",
    )
