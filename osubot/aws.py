import json
import os
import tempfile
import time
import traceback

from pathlib import Path
from typing import Any, Dict, Optional, Union

import boto3

from botocore.exceptions import ClientError

_bucket = boto3.resource("s3").Bucket(os.getenv("S3_BUCKET", ""))
_lambda = boto3.client("lambda")
_lambda_prefix = os.getenv("LAMBDA_PREFIX", "")
_table = boto3.resource("dynamodb").Table(os.getenv("DYNAMODB_TABLE", ""))


def ddb_get_item(key: str) -> Optional[Dict[str, Union[int, str]]]:
    """Get an item from DynamoDB."""
    resp = _table.get_item(Key=_ddb_key(key))
    if "Item" not in resp:
        return None
    item = resp["Item"]
    for k, v in item.items():
        vtype = list(v.keys())[0]
        vval = v[vtype]
        if vtype == "N":
            item[k] = int(vval)
        else:
            item[k] = vval
    return item


# TODO: Deal with weird typing issues.
# We only really need to support str -> str but ttl messes that up a bit.


def ddb_put_item(key: str, item: Dict[str, Union[int, str]], ttl: bool = False) -> None:
    """Put an item into DynamoDB."""
    if ttl:
        item["ttl"] = round(time.time()) + 60 * 60 * 24 * 14
    _table.put_item(Item=_ddb_item(item))


def ddb_update_item(key: str, item: Dict[str, Union[int, str]]) -> None:
    _table.update_item(Key=_ddb_key(key), AttributeUpdates=_ddb_item(item))


def s3_get_object(key: str, dest: Optional[Path] = None) -> Optional[Path]:
    """Download a file from S3 and return the path on disk."""
    if dest is None:
        _, path = tempfile.mkstemp()
        dest = Path(path)
    try:
        _bucket.download_file(key, dest)
    except ClientError:
        traceback.print_exc()
        return None
    return dest


def s3_put_object(key: str, file: Path) -> None:
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


def _ddb_key(key: str) -> Dict[str, Dict[str, str]]:
    return {"id": {"S": key}}


def _ddb_item(item: Dict[str, Union[str, int]]) -> Dict[str, Dict[str, str]]:
    return {k: {"N" if isinstance(v, int) else "S": str(v)} for k, v in item.items()}
