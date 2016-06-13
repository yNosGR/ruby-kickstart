#!/usr/bin/env ruby
# rubocop: disable UnusedLocalVariable

require 'cgi'
require 'erb'
require 'resolv'
require 'socket'
require 'ipaddr'

# set up CGI object
cgi = CGI.new

snapshot = (cgi.has_key?('snapshot') ? cgi['snapshot'] : 'kickstart')

# only one nameserver for initial kickstart, chef bootstrap will flesh 'em out
SUBNETS = {
#  x.x.x.x/xx      => [netmask,         gateway,          nameserver(s)],
# lab
  '10.168.131.0/24' => ['255.255.255.0', '10.168.131.1', '10.201.26.100'],
  '10.57.128.70/23' => ['255.255.254.0', '10.57.128.1',  '10.201.26.100']
}
SITES = {
##NOC # area #mode # mode data
  'ctis' => ['lab', 'nfs', {'server' => 'nfs-server.domain.org',
                                    'dir' => "/shares/tier3/UNIX/linux_depot/centos/7/os/x86_64/",
                                    'opts' => 'defaults,ro,nfsvers=3'}]
}

# helper function to ease embedded templates
def render(filename, eoutvar)
  content = File.read(filename)
  erb = ERB.new(content, nil, '<>', eoutvar = eoutvar)
  erb.result
end

# get cgi parameters
site, install_method, install_params = SITES[Socket.gethostname.split('.')[0]]
site, install_method, install_params = SITES['ctis'] if site.nil?

template = cgi['template']
template.empty? && template = 'default'

fs = cgi['fs']
fs.empty? && fs = 'default'

novm = cgi.key? 'novm'
distroyum = cgi.key? 'distroyum'

# if there's an hostname, fetch the IP address, netmask, gateway, and nameserver
hostname = cgi['hostname']
unless hostname.empty?
  hostname += '.spectrum-health.org' unless hostname.include? '.'
  begin
    ip = Resolv.getaddress(hostname)
  rescue
    abort("unable to resolve hostname: #{hostname}")
  end

  netmask = gateway = nameserver = nil
  SUBNETS.each do |subnet, subnetinfo|
    netmask, gateway, nameserver = subnetinfo if IPAddr.new(subnet).include?(IPAddr.new(ip))
  end
  abort("unrecognized ip address: #{ip}") unless netmask
end

# kick out the jams
cgi.out('text/plain') { render("ks/#{template}.erb", '_main') }
