"""
Wrapper around oppai.
"""
module Oppai

log(msg::AbstractString) = info("$(basename(@__FILE__)): $msg")

end
