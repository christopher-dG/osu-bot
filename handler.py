import os
import osubot
import shutil
import stat


def handler(event, _):
    oppai = osubot.consts.oppai
    shutil.copyfile("oppai", oppai)
    os.chmod(oppai, os.stat(oppai).st_mode | stat.S_IEXEC)
    return osubot.main(event["queryStringParameters"]["title"])
