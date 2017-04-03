# Path to oppai binary.
OPPAI = File.expand_path("#{File.dirname(__FILE__)}/../oppai/oppai")

# Vertical line delimiter that won't break Markdown tables.
BAR = '&#124;'

# Base for API requests.
OSU_URL = 'https://osu.ppy.sh'

# Log file.
LOG = File.expand_path(
  "#{File.dirname(__FILE__)}/../logs/#{`date +"%m-%d-%Y_%H:%M"`.chomp}"
)

# Modes to run in.
# 'DEBUG' -> Enable extra logging (todo), 'DRY' -> dry run, 'TEST' -> testing.
RUN_MODES = ['DEBUG', 'DRY', 'TEST']
DEBUG = ARGV.include?("DEBUG")
DRY = ARGV.include?("DRY")
TEST = ARGV.include?("TEST")

# Secret files.
SECRETS = File.expand_path("#{File.dirname(__FILE__)}/../secrets")
OSU_KEY = File.open("#{SECRETS}/key").read.chomp
REDDIT_PASSWORD = File.open("#{SECRETS}/pass").read.chomp
REDDIT_SECRET = File.open("#{SECRETS}/secret").read.chomp
REDDIT_CLIENT_ID = File.open("#{SECRETS}/client").read.chomp
OSUSEARCH_KEY = File.open("#{SECRETS}/search_key").read.chomp

# All mods.
MODS = [
  'EZ', 'NF', 'HT', 'HR', 'SD', 'PF', 'DT',
  'NC', 'HD', 'FL', 'RL', 'AP', 'SO', 'AT',
]

# Mods that don't affect difficulty values.
NO_DIFF_MODS = ['SD', 'PF', 'AP', 'RL']

# Mods that don't affect pp values.
NO_PP_MODS = ['SD', 'PF']

# Mods that don't give any pp.
ZERO_PP_MODS = ['RL', 'AP', 'AT']

# Integer mods according to: https://github.com/ppy/osu-api/wiki#mods
BITWISE_MODS = {
  0 => '',
  1 => 'NF',
  2 => 'EZ',
  8 => 'HD',
  16 => 'HR',
  32 => 'SD',
  64 => 'DT',
  128 => 'RL',
  256 => 'HT',
  512 => 'NC',  # Always includes DT as well: NC = 576.
  1024 => 'FL',
  2048 => 'AT',
  4096 => 'SO',
  8192 => 'AT',
  16384 => 'PF',
}
