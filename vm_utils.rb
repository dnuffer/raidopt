require 'fileutils'

VIM = RbVmomi::VIM

class TimeoutException < StandardError
end

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

def process_is_running(vm, guestauth, pid)
  $guestProcessManager = $vim.serviceContent.guestOperationsManager.processManager unless $guestProcessManager
  procs = $guestProcessManager.ListProcessesInGuest(:vm => vm, :auth => guestauth, :pids => [pid])
  procs.empty? || procs.any? { |gpi| gpi.exitCode == nil }
end

def process_exit_code(vm, guestauth, pid)
  $guestProcessManager = $vim.serviceContent.guestOperationsManager.processManager unless $guestProcessManager
  $guestProcessManager.ListProcessesInGuest(:vm => vm, :auth => guestauth, :pids => [pid])[0].exitCode
end

def wait_for_process_exit(vm, guestauth, pid, limit=60)
  waitTime = 0
  while process_is_running(vm, guestauth, pid) && waitTime < limit
    waitTime += 1
    sleep(1)
  end
  if waitTime >= limit
    raise TimeoutException, "gave up waiting for process #{pid} to exit after #{limit} seconds"
  end
end

def run_program(vm, guestauth, path, args="", limit=60)
  puts "run_program: #{path} #{args}"
  $guestProcessManager = $vim.serviceContent.guestOperationsManager.processManager unless $guestProcessManager

  pid = $guestProcessManager.StartProgramInGuest(:vm => vm, :auth => guestauth, :spec => VIM::GuestProgramSpec.new(:programPath => path, :arguments => args))
  wait_for_process_exit(vm, guestauth, pid, limit)
  exit_code = process_exit_code(vm, guestauth, pid)
  raise "failed to run #{path} #{args}. exit_code: #{exit_code}" if exit_code != 0
end

def run_shell_capture_output(vm, guestauth, command, limit=60)
  $guestProcessManager = $vim.serviceContent.guestOperationsManager.processManager unless $guestProcessManager

  tmp_out_fname = "/tmp/vm_utils_run_out_#{Random.rand}"
  tmp_err_fname = "/tmp/vm_utils_run_err_#{Random.rand}"
  args = "-c '(#{command.gsub("'", %q(\\\'))}) > #{tmp_out_fname} 2> #{tmp_err_fname}'"
  puts "run_shell_capture_output: /bin/sh #{args}"
  STDOUT.flush
  pid = $guestProcessManager.StartProgramInGuest(:vm => vm, :auth => guestauth, :spec => VIM::GuestProgramSpec.new(:programPath => "/bin/sh", :arguments => args))
  wait_for_process_exit(vm, guestauth, pid, limit)
  exit_code = process_exit_code(vm, guestauth, pid)
  copy_file_from_vm(vm, guestauth, tmp_out_fname, tmp_out_fname)
  copy_file_from_vm(vm, guestauth, tmp_err_fname, tmp_err_fname)
  proc_out = open(tmp_out_fname) { |f| f.read }
  proc_err = open(tmp_err_fname) { |f| f.read }
  FileUtils.rm_f([tmp_out_fname, tmp_err_fname])
  raise "failed to run #{command}. exit_code: #{exit_code}. stdout:\n#{proc_out}\nstderr:\n#{proc_err}" if exit_code != 0
  return [proc_out, proc_err]
end

def copy_files_to_vm(vm, guestauth, src_dir, dst_dir)
  Find.find(src_dir) do |path|
    if path == '.'
      next
    end

    dst_path = Pathname.new("#{dst_dir}/#{path}").cleanpath.to_s

    if File.directory?(path)
      mkdir(dst_path)
    else
      copy_file_to_vm(vm, guestauth, path, dst_path)
    end
  end
end

def copy_file_to_vm(vm, guestauth, src_path, dst_path)
  $guestFileManager = $vim.serviceContent.guestOperationsManager.fileManager unless $guestFileManager

  fileAttributes = RbVmomi::VIM::GuestPosixFileAttributes(:permissions => File::stat(src_path).mode)
  url = $guestFileManager.InitiateFileTransferToGuest(:vm => vm, :auth => guestauth, :guestFilePath => dst_path, :fileAttributes => fileAttributes, :fileSize => File::stat(src_path).size, :overwrite => true)
  url.gsub!(/\/\*/, "/#{vm._connection.host}")
  uploadCmd = "curl -X PUT --insecure -T #{src_path} '#{url}' >/dev/null 2>/dev/null"
  system(uploadCmd)
end

def copy_file_from_vm(vm, guestauth, src_path, dst_path)
  FileUtils.rm_f([dst_path])
  $guestFileManager = $vim.serviceContent.guestOperationsManager.fileManager unless $guestFileManager

  fileTransferInformation = $guestFileManager.InitiateFileTransferFromGuest(:vm => vm, :auth => guestauth, :guestFilePath => src_path)
  url = fileTransferInformation.url.gsub(/\/\*/, "/#{vm._connection.host}")
  curlCmd = "curl --insecure --fail '#{url}' > #{dst_path}"
  puts "copying #{src_path} to #{dst_path} by #{curlCmd}"
  raise "Failed copying #{src_path} from vm" unless system(curlCmd)
  raise "#{dst_path} is not the right size. expected #{fileTransferInformation.size}, is #{File.stat(dst_path).size}" unless File.stat(dst_path).size == fileTransferInformation.size
end

def resize_disk(vm, size_in_bytes, busNumber, unitNumber)
  controller_type = RbVmomi::VIM::VirtualSCSIController

  controller = vm.config.hardware.device.grep(controller_type).find { |x| x.busNumber == busNumber }

  raise "Controller with type VirtualSCSIController and bus #{busNumber} was not found" unless controller

  child_keys = controller.device
  child_disks = vm.disks.select { |x| child_keys.include?(x.key) }
  disk = child_disks.find { |x| x.unitNumber == unitNumber }

  raise "Disk with type VirtualSCSIController, bus #{busNumber}, unit #{unitNumber} was not found" unless disk

  disk.capacityInKB = (size_in_bytes / 1024).to_i

  dev = { 
    :operation => :edit,
    :device => disk
  }

  spec = {
    :deviceChange => [ RbVmomi::VIM.VirtualDeviceConfigSpec(dev) ]
  }

  vm.ReconfigVM_Task( :spec => RbVmomi::VIM.VirtualMachineConfigSpec(spec) ).wait_for_completion
end

def resize_memory(vm, size_mb)
  puts "resizing memory to #{size_mb}"
  vm.ReconfigVM_Task( :spec => RbVmomi::VIM.VirtualMachineConfigSpec({ :memoryMB => size_mb.to_i }) ).wait_for_completion
end

def resize_cpus(vm, num_cpus)
  vm.ReconfigVM_Task( :spec => RbVmomi::VIM.VirtualMachineConfigSpec({ :numCPUs => num_cpus.to_i }) ).wait_for_completion
end
