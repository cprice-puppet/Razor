# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

module ProjectRazor
  module Policy
    # ProjectRazor Policy Default class
    # Used for default booting of Razor MK
    class BootMK< ProjectRazor::Policy::Base

      # @param hash [Hash]
      def initialize
        super

        @policy_type = :mkboot

        @data = ProjectRazor::Data.new
        @config = @data.config
      end

      # TODO - add logging ability from iPXE back to Razor for detecting node errors

      def get_boot_script
        image_svc_uri = "http://#{@config.image_svc_host}:#{@config.image_svc_port}/razor/image"
        boot_script = ""
        boot_script << "#!ipxe\n"
        boot_script << "initrd #{image_svc_uri}/mk || goto error\n"
        boot_script << "chain #{image_svc_uri}/memdisk iso || goto error\n"
        boot_script << "\n\n\n"
        boot_script << ":error\nsleep #{@config.mk_checkin_interval}\nreboot\n"
        boot_script
      end
    end
  end
end