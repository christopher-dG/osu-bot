import osubot


def handler(event, _): osubot.main(event["queryStringParameters"]["title"])
