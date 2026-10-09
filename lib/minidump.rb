require "bindata"

class MiniDump < BinData::Record
  class Dir < BinData::Record; end
  class ExceptionStream < BinData::Record; end
  class SystemInfo < BinData::Record; end
  class MiscInfo < BinData::Record; end

  STREAM_TYPES = {
    6 => ExceptionStream,
    7 => SystemInfo,
    15 => MiscInfo
  }.freeze

  class Header < BinData::Record
    endian :little

    string :magic1, read_length: 4, assert: "MDMP"
    uint16 :magic2, assert: 0xa793

    uint16 :version
    uint32 :num_streams
    uint32 :ofs_streams
    uint32 :checksum
    uint32 :timestamp
    uint64 :flags

    array :streams, initial_length: :num_streams do
      uint32 :stream_type
      struct :location do
        uint32 :data_size
        uint32 :offset
      end
    end
  end

  class ExceptionStream < BinData::Record
    endian :little

    uint32 :thread_id
    uint32 :__alignment
    # https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/ns-minidumpapiset-minidump_exception
    struct :exception do
      uint32 :exception_code
      uint32 :exception_flags
      uint64 :exception_record
      uint64 :exception_address
      uint32 :number_parameters
      uint32 :__unused_alignment
      array :exception_information, initial_length: -> { number_parameters } do
        uint32 :thread_id
        struct :exception_pointers do
          uint32 :exception_record
          uint32 :context_record
        end
        bit1 :client_pointers
      end
    end
  end


  class SystemInfo < BinData::Record
    endian :little

    uint16 :cpu_arch
    uint16 :cpu_level
    uint16 :cpu_revision
    uint8 :num_cpus
    uint8 :product_type

    uint32 :os_version_major
    uint32 :os_version_minor
    uint32 :os_build_number
    uint32 :os_platform_id
    uint32 :_rva_os_service_pack
    uint16 :os_suite_mask
    uint16 :_reserved

    struct :cpu_info do
      uint32 :vendor_id
      uint32 :_unknown_vendor_id_b
      uint32 :_unknown_vendor_id_c
      uint32 :version_information
      uint32 :feature_information
      uint32 :amd_extended_cpu_features
    end
  end

  # https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/ns-minidumpapiset-minidump_misc_info_2
  class MiscInfo < BinData::Record
    endian :little

    uint32 :sizeof_info
    uint32 :flags
    uint32 :process_id
    uint32 :process_creation_time
    uint32 :process_user_time
    uint32 :process_kernel_time

    # https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/ns-minidumpapiset-minidump_misc_info_2
    uint32 :processor_max_mhz, onlyif: -> { sizeof_info > 24 }
    uint32 :processor_current_mhz, onlyif: -> { sizeof_info > 24 }
    uint32 :processor_mhz_limit, onlyif: -> { sizeof_info > 24 }
    uint32 :processor_max_idle_state, onlyif: -> { sizeof_info > 24 }
    uint32 :processor_current_idle_state, onlyif: -> { sizeof_info > 24 }
  end
end

# class MiniDump < BinData::Record
#   endian :little

#   header :header
# end

# file = "/home/cyberarm/Documents/W3D Hub/games/ar-release/debug/crashdump.20260129-003917-r13285-n1.dmp"
# file = "/home/cyberarm/Downloads/crashdump.20261001-150617-r13830-n1.dmp"
file = "/home/cyberarm/Downloads/crashdump.20261002-202438-r13779-n1-lim.dmp"
# file = "/home/cyberarm/Downloads/crashdump.20261002-202438-r13779-n1-ext.dmp"
File.open(file, "rb") do |f|
  mini = MiniDump::Header.read(f)
  pp mini

  stream = mini.streams.find { |stream| stream[:stream_type] == 7 }
  if stream
    f.pos = stream.location.offset
    stream = MiniDump::SystemInfo.read(f.read(stream.location.data_size))
    # pp [stream.class, stream]
  end

  misc = mini.streams.find { |stream| stream[:stream_type] == 15 }
  if misc
    f.pos = misc.location.offset
    misc = MiniDump::MiscInfo.read(f.read(misc.location.data_size))
    # pp [misc.class, misc]
  end

  stream = mini.streams.find { |stream| stream[:stream_type] == 6 }
  if stream
    f.pos = stream.location.offset
    pp [f.pos, stream.location.data_size, f.size]
    stream = MiniDump::ExceptionStream.read(f.read(stream.location.data_size))
    # pp [stream.class, stream]
  end
  # pp mini
  # pp Time.at(mini.timestamp)
end
