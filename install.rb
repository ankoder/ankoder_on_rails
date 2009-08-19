# plugin_install install script
require 'fileutils'

def install(file)
  puts "Copying: #{file}"
  target = File.join(File.dirname(__FILE__), '..', '..', '..', file)
  if File.exists?(target)
    puts "target #{target} already exists, skipping"
  else
    FileUtils.cp File.join(File.dirname(__FILE__), file), target
  end
end

install File.join( 'config', 'ankoder.yml' )
p "."
puts IO.read(File.join(File.dirname(__FILE__), 'README'))
