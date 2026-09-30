# Shared baseline plus an explicit machine profile.
profile = ENV["MAC_ENV_PROFILE"]
if profile.nil? || profile.empty?
  machine = IO.popen(["/usr/sbin/scutil", "--get", "ComputerName"], &:read).strip
  profile = {
    "Shannon MBP 13 - M1 (2020)" => "shannon",
    "PHL MBP 16 - M1X (2021)" => "phl",
  }[machine]
end
raise "Select MAC_ENV_PROFILE=shannon or phl" unless %w[shannon phl].include?(profile)
["common", profile].each do |name|
  path = File.join(__dir__, "brew", "Brewfile.#{name}")
  instance_eval(File.read(path), path)
end
