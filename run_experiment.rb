require 'rubygems'
require 'rbvmomi'
require 'highline/import'

raise "Invalid args: template password" unless ARGV.size == 1
template = ARGV[0]

password = 'temppassword'
#password = ask("password?") {|q| q.echo = false}
VIM = RbVmomi::VIM
$vim = VIM.connect host: 'vc', user: 'root', password: password, insecure: true
dc = $vim.serviceInstance.find_datacenter("dc1") or fail "datacenter not found"


# First look if the target vm already exists. if so, shut it off and delete it.
target_vm = dc.find_vm("disktest-vm")
if target_vm
  puts "Found target, powering off"
  target_vm.PowerOffVM_Task.wait_for_completion rescue nil
  puts "Deleting target"
  target_vm.Destroy_Task.wait_for_completion
  puts "target deleted"
  target_vm = nil
end


template_vm = dc.find_vm(template) or fail "VM template #{template} not found"
puts "Found template"

target_datastore = dc.find_datastore("local-black-ssd-raid0")
puts "Found target datastore"

relocateSpec = VIM.VirtualMachineRelocateSpec(:diskMoveType => :moveAllDiskBackingsAndDisallowSharing)
relocateSpec.transform = :flat
relocateSpec.datastore = target_datastore
#relocateSpec.host = opts[:host] if opts[:host]
#relocateSpec.pool = opts[:pool] if opts[:pool]
cluster = dc.find_compute_resource 'cluster1'
relocateSpec.host = cluster.host.find {|h| h.name == "black.home.nuffer.name" }
relocateSpec.pool = cluster.resourcePool
#relocateSpec = VIM.VirtualMachineRelocateSpec(:datastore => target_datastore)
spec = VIM.VirtualMachineCloneSpec(:location => relocateSpec,
                                   :powerOn => false,
                                   :template => false)

puts "Starting clone of template"
vm = template_vm.CloneVM_Task(:folder => template_vm.parent, :name => "disktest-vm", :spec => spec).
  wait_for_progress { |progress|
    puts progress
  }
puts "Finished clone of template"

puts "Powering on vm"
vm.PowerOnVM_Task.wait_for_completion
puts "VM Powered on"

def make_temp_dir_on_guest(vm, guestauth, prefix="foo", suffix="bar")
  $guestFileManager = $vim.serviceContent.guestOperationsManager.fileManager unless $guestFileManager
  $guestFileManager.CreateTemporaryDirectoryInGuest(:vm => vm, :auth => guestauth, :prefix => prefix, :suffix => suffix)
end

def delete_dir(vm, guestauth, dir)
  $guestFileManager = $vim.serviceContent.guestOperationsManager.fileManager unless $guestFileManager
  $guestFileManager.DeleteDirectoryInGuest(:vm => vm, :auth => guestauth, :directoryPath => dir, :recursive => true)
end

def wait_for_tools(vm, guestauth, limit = 5 * 60)
  waitTime = 0
  while !vm.guest.guestOperationsReady && waitTime < limit
    waitTime += 1
    sleep(1)
  end
  if waitTime >= limit
    raise "guest operation not ready in #{limit} seconds"
  end

  # test creating a temp dir. This may fail with GuestComponentsOutOfDate, in which case wait and try again
  while waitTime < limit
    begin
      tempdir = make_temp_dir_on_guest(vm, guestauth)
      break
    rescue RbVmomi::Fault => e
      if e.fault.class.wsdl_name == "InvalidGuestLogin"
        raise e
      else
        sleep(5)
      end
    end
    waitTime += 5
  end
  if tempdir
    delete_dir(vm, guestauth, tempdir)
  end

  waitTime
end

guestauth = VIM::NamePasswordAuthentication(:interactiveSession => false,
          :username => 'root', :password => 'password')

puts "Waiting for VMware tools"
wait_for_tools(vm, guestauth)
puts "VMware tools available"


def process_is_running(vm, pid)
  $guestProcessManager = $vim.serviceContent.guestOperationsManager.processManager unless $guestProcessManager
  procs = $guestProcessManager.ListProcessesInGuest(:vm => vm, :auth => $guestauth, :pids => [pid])
  procs.empty? || procs.any? { |gpi| gpi.exitCode == nil }
end

def process_exit_code(vm, pid)
  $guestProcessManager = $vim.serviceContent.guestOperationsManager.processManager unless $guestProcessManager
  $guestProcessManager.ListProcessesInGuest(:vm => vm, :auth => $guestauth, :pids => [pid])[0].exitCode
end

def wait_for_process_exit(vm, pid, limit=60)
  waitTime = 0
  while process_is_running(vm, pid)
    waitTime += 1
    sleep(1)
  end
  if waitTime >= limit
    raise "gave up waiting for process #{pid} to exit after #{limit} seconds"
  end
end

def run_program(vm, path, args="", limit=60)
  $guestProcessManager = $vim.serviceContent.guestOperationsManager.processManager unless $guestProcessManager

  pid = $guestProcessManager.StartProgramInGuest(:vm => vm, :auth => $guestauth, :spec => VIM::GuestProgramSpec.new(:programPath => path, :arguments => args))
  wait_for_process_exit(vm, pid, limit)
  return process_exit_code(vm, pid)
end


puts "running phoronix test suite"
twelve_hours_in_secs = 12 * 60 * 60
run_program(vm, "/home/dan/benchmark.sh", "", twelve_hours_in_secs)
puts "phoronix test suite complete"
