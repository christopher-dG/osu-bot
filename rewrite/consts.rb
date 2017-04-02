SECRETS_DIR = File.expand_path("#{File.dirname(__FILE__)}/../secrets")
OPPAI = File.expand_path("#{File.dirname(__FILE__)}/../oppai/oppai")
URL = 'https://osu.ppy.sh'  # Base for API requests.
KEY = File.open("#{SECRETS_DIR}/key").read.chomp
PASSWORD = File.open("#{SECRETS_DIR}/pass").read.chomp
SECRET = File.open("#{SECRETS_DIR}/secret").read.chomp
CLIENT_ID = File.open("#{SECRETS_DIR}/client").read.chomp
OSUSEARCH_KEY = File.open("#{SECRETS_DIR}/search_key").read.chomp
LOG = File.expand_path("#{File.dirname(__FILE__)}/../logs/#{now}#{ARGV.length > 0 ? -ARGV[0] : ''}")
# All mods.
MODS = [
  'EZ', 'NF', 'HT', 'HR', 'SD', 'PF', 'DT',
  'NC', 'HD', 'FL', 'RL', 'AP', 'SO'
]
# Mods that either don't give affect difficulty or don't give pp.
NO_DIFF_MODS = ['SD', 'PF', 'AP', 'RL']
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
BAR = '&#124;'  # Vertical line delimiter that won't break Markdown tables.
