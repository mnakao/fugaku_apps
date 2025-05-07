EXCLUDED_GROUPS = ["f-op", "fugaku", "trial", "oss-adm"] # "Group names starting with "isv" are deleted in the code.

def favorites()
  user = ENV['USER']
  groups = `groups`.split
  favorites = ["      - #{Dir.home}"]

  groups.each do |group|
    next if group.start_with?("isv")

    ["/data", "/share", "/2ndfs"].each do |base|
      dir_user = File.join(base, group, user)
      dir_group = File.join(base, group)

      if File.directory?(dir_user)
        favorites << "      - \"#{dir_user}\""
      elsif File.directory?(dir_group)
        favorites << "      - \"#{dir_group}\""
      end
    end
  end

  return nil if favorites.empty?

  "favorites:\n" + favorites.join("\n") + "\n"
end

def default_dir()
  user = ENV['USER']

  `groups`.split.each do |group|
    next if group.start_with?("isv")

    [File.join("/data", group, user), File.join("/data", group)].each do |path|
      return path if File.directory?(path)
    end
  end

  Dir.home
end

def header(check_script_content = false, appname = nil)
  yaml = <<-YAML
  _script_location:
    widget:     path
    value:      #{default_dir()}
    label:      Script Location
    show_files: false
    required:   true
    #{favorites()}

  _script:
    widget:   text
    size :    2
    label:    [Script Name, Job Name]
    value:    [job.sh, ""]
    required: [true, false]
YAML

  if appname == "OpenFOAM"
    yaml << <<-YAML
  _cluster_name:
    widget: select
    label: Cluster name
    required: true
    direction: horizontal
    value: fugaku
    options:
      - [ Fugaku,  "linux-rhel8-a64fx", enable-rsc_group, enable-nodes_procs, enable-time, enable-group, enable-show_advanced_option, enable-mode, enable-mail_option, enable-mail, emable-stat, enable-stat_file_name, enable-gfscache ]
      - [ Prepost, "linux-rhel8-cascadelake", enable-prepost_partiton, enable-prepost_time, enable-prepost_cores, enable-prepost_memory ]
YAML
  elsif appname == "Slurm"
    yaml << <<-YAML
  _cluster_name:
    widget: select
    label: Cluster name
    required: true
    direction: horizontal
    value: fugaku
    options:
      - [ Prepost, Prepost, hide-_cluster_name ]
YAML
  end
      
  if check_script_content
    yaml << <<-YAML
  script_content:
    widget: checkbox
    value: ["Hide script content"]
    options:
      - ["Hide script content", "", hide-#{SCRIPT_CONTENT}]
    YAML
  end

  return yaml
end

def submit()
  <<-BASH
  #!/bin/bash
  OC_SUBMIT_OPTIONS=\"--no-check-directory\"
BASH
end

def form_rsc_group(rsc_group, enable_threads)
  yaml = <<-YAML
  rsc_group:
    widget: select
    direction: horizontal
    label: Resource group
    required: true
    value: small
    help: See <a target="_blank" href="https://www.fugaku.r-ccs.riken.jp/en/resource_group_config">Resource group configuration</a> for details.
    options:
YAML

  prefix = enable_threads ? "nodes_procs_threads" : "nodes_procs"
  if rsc_group == "small_and_large"
    yaml << "      - [ small     , small,      disable-llio_comment, disable-llio_exec_file_transfer, disable-llio_file_transfer, disable-llio_dir_transfer ]\n"
    yaml << "      - [ spot-small, spot-small, disable-llio_comment, disable-llio_exec_file_transfer, disable-llio_file_transfer, disable-llio_dir_transfer, set-label-time_1: Maximum hours (0 - 4), set-max-time_1: 4 ]\n"
    yaml << "      - [ large,      large,      set-label-#{prefix}_1: \"Nodes (385 - 12,288)\", set-min-#{prefix}_1: 385, set-max-#{prefix}_1: 12288, set-min-#{prefix}_2: 385, set-max-#{prefix}_2: 589824, set-label-#{prefix}_2: \"Procs (385 - 589,824)\", set-label-time_1: Maximum hours (0 - 24), set-max-time_1: 24, enable-llio, enable-tofu_eager_limit ]\n"
    yaml << "      - [ spot-large, spot-large, set-label-#{prefix}_1: \"Nodes (385 - 12,288)\", set-min-#{prefix}_1: 385, set-max-#{prefix}_1: 12288, set-min-#{prefix}_2: 385, set-max-#{prefix}_2: 589824, set-label-#{prefix}_2: \"Procs (385 - 589,824)\", set-label-time_1: Maximum hours (0 - 4),  set-max-time_1: 4,  enable-llio, enable-tofu_eager_limit ]\n"
    yaml << "      - [ f-pt,       f-pt,       set-label-#{prefix}_1: \"Nodes (1 - 12,288)\",   set-min-#{prefix}_1:   1, set-max-#{prefix}_1: 12288, set-min-#{prefix}_2:   1, set-max-#{prefix}_2: 589824, set-label-#{prefix}_2: \"Procs (1 - 589,824)\",   set-label-time_1: Maximum hours (0 - 24), set-max-time_1: 24, enable-llio, enable-tofu_eager_limit ]\n"
    # enable-tofu_eager_limit is defined in FFVHC-ACE
  elsif rsc_group == "small"
    yaml << "      - [ small,      small ]\n"
    yaml << "      - [ spot-small, spot-small, set-label-time_1: Maximum hours (0 - 4), set-max-time_1: 4 ]\n"
    yaml << "      - [ f-pt,       f-pt,       set-label-#{prefix}_1: \"Nodes (1 - 12,288)\", set-min-#{prefix}_1: 1, set-max-#{prefix}_1: 12288, set-min-#{prefix}_2: 1, set-max-#{prefix}_2: 589824, set-label-#{prefix}_2: \"Procs (1 - 589,824)\", set-label-time_1: Maximum hours (0 - 24), set-max-time_1: 24 ]\n"
  elsif rsc_group == "single"
    yaml << "      - [ small     , small ]\n"
    yaml << "      - [ spot-small, spot-small, set-label-time_1: Maximum hours (0 - 4),  set-max-time_1:  4 ]\n"
    yaml << "      - [ f-pt,       f-pt,       set-label-time_1: Maximum hours (0 - 24), set-max-time_1: 24 ]\n"
  end

  return yaml
end

def threads()
  <<-YAML
  threads:
    widget: number
    value:  1
    min:    1
    max:   48
    step:   1
    label: "Threads (1 - 48)"
    required: true
YAML
end

def nodes_procs()
  <<-YAML
  nodes_procs:
    widget: number
    size: 2
    value: [   1,     1 ]
    min:   [   1,     1 ]
    max:   [ 384, 18432 ]
    step:  [   1,     1 ]
    label: [ "Nodes (1 - 384)", "Procs (1 - 18,432)" ]
    required: [ true, true ]
    help: "\\"Nodes x 48 >= Procs\\" must hold."
YAML
end

def nodes_procs_threads()
  <<-YAML
  nodes_procs_threads:
    widget: number
    size: 3
    value: [   1,     1,  1 ]
    min:   [   1,     1,  1 ]
    max:   [ 384, 18432, 48 ]
    step:  [   1,     1,  1 ]
    label: [ "Nodes (1 - 384)", "Procs (1 - 18,432)", "Threads (1 - 48)" ]
    required: [ true, true, true ]
    help: "\\"Nodes x 48 >= Procs x Threads\\" must hold."
YAML
end

def prepost_common()
  form = <<-YAML
  prepost_partiton:
    widget: select
    label: Partition
    required: true
    options:
      - [ gpu1, gpu1, set-max-prepost_time_1: 3, set-label-prepost_time_1: Maximum hours (0 - 3), set-max-prepost_cores:  72, set-label-prepost_cores: Number of CPU cores (1 - 72),  set-max-prepost_memory:  186, set-label-prepost_memory: Memory (5 - 186GB)  ]
      - [ gpu2, gpu2,                                                                             set-max-prepost_cores:  36, set-label-prepost_cores: Number of CPU cores (1 - 36),  set-max-prepost_memory:   93, set-label-prepost_memory: Memory (5 - 93GB)   ]
      - [ mem1, mem1, set-max-prepost_time_1: 3, set-label-prepost_time_1: Maximum hours (0 - 3), set-max-prepost_cores: 224, set-label-prepost_cores: Number of CPU cores (1 - 224), set-max-prepost_memory: 5020, set-label-prepost_memory: Memory (5 - 5020GB) ]
      - [ mem2, mem2,                                                                             set-max-prepost_cores:  56, set-label-prepost_cores: Number of CPU cores (1 - 56),  set-max-prepost_memory: 1500, set-label-prepost_memory: Memory (5 - 1500GB) ]

  prepost_time:
    widget: number
    label:    [ Maximum hours (0 - 24), Maximum minutes (0 - 59) ]
    size:     2
    max:      [ 24, 59 ]
    min:      [  0,  0 ]
    value:    [  1,  0 ]
    required: [ true, true ]

  prepost_cores:
    widget: number
    label: Number of CPU cores
    min: 1
    value: 1
    required: true

  prepost_memory:
    widget: number
    label: Memory
    min: 5
    value: 5
    required: true
YAML
end

def fugaku_common(rsc_group, enable_threads = true, check_script_content = false, app_name = nil)
  form = form_rsc_group(rsc_group, enable_threads)

  if rsc_group == "single" && enable_threads
    form << threads()
  elsif rsc_group != "single" && !enable_threads
    form << nodes_procs()
  elsif rsc_group != "single" && enable_threads
    form << nodes_procs_threads()
  end
    
  form << <<-YAML
  time:
    widget:   number
    label:    [ Maximum hours (0 - 72), Maximum minutes (0 - 59) ]
    size:     2
    value:    [  1,  0 ]
    min:      [  0,  0 ]
    max:      [ 72, 59 ]
    step:     [  1,  1 ]
    required: [ true, true]

  group:
    widget: select
    label: Group
    required: true
    options:
YAML
  groups = `groups`.split - EXCLUDED_GROUPS
  groups.each do |g|
    form << "      - [\"" + g + "\" , \"" + g + "\"]\n" unless g.start_with?("isv")
  end
  form << "      - [\"(None)\", \"\"]\n"
  
  form << <<-YAML  
  show_advanced_option:
    widget: checkbox
    options:
    - [ 'Show advanced option', '', show-mode, show-stat, show-mail, show-mail_option, show-gfscache ]

  mode:
    widget: radio
    label: Execution mode
    direction: horizontal
    indent: 1
    value: "Boost Eco"
    options:
      - [Boost Eco, "#PJM -L \\"freq=2200,eco_state=2\\""]
      - [Normal,    "#PJM -L \\"freq=2000,eco_state=0\\""]
      - [Eco,       "#PJM -L \\"freq=2000,eco_state=2\\""]
      - [Boost,     "#PJM -L \\"freq=2200,eco_state=0\\""]
    help: Please refer to the manual for details in <a target="_blank" href="https://www.fugaku.r-ccs.riken.jp/doc_root/en/user_guides/use_latest/PowerControlFunction/index.html">English</a> or <a target="_blank" href="https://www.fugaku.r-ccs.riken.jp/doc_root/ja/user_guides/use_latest/PowerControlFunction/index.html">Japanese</a>.

  mail_option:
    widget: checkbox
    label: Mail option
    direction: horizontal
    separator: ","
    indent: 1
    options:
      - [Beginning of job execution, b, enable-mail]
      - [End of job execution, e, enable-mail]
      - [Restart of job, r, enable-mail]
      - [Statistics without node information, s, disable-mail_option-Statistical information with node information, enable-mail]
      - [Statistics with node information, S, disable-mail_option-Statistical information without node information, enable-mail]

  mail:
    widget: email
    label: Mail Address
    required: true
    indent: 2

  stat:
    widget: radio
    label: Output statistics information
    direction: horizontal
    indent: 1
    value: (None)
    options:
      - ["(None)",  "", disable-stat_file_name]
      - ["Statistics without node information", "-s"]
      - ["Statistics with node information", "-S"]

  stat_file_name:
    widget: text
    label: Statistics file name
    indent: 2

  gfscache:
    widget: checkbox
    label: Volume of data area
    separator: ":"
    direction: horizontal
    value: "/vol0004"
    indent: 1
    options:
      - ["/vol0002", "/vol0002"]
      - ["/vol0003", "/vol0003"]
      - ["/vol0004", "/vol0004"]
      - ["/vol0005", "/vol0005"]
      - ["/vol0006", "/vol0006"]
    help: "If you use spack, you may need /vol0004."
YAML

  script = "  #!/bin/bash\n"
  script << "  #PJM -L \"rscgrp=\#{rsc_group}\"\n"

  if rsc_group != "single"
    if enable_threads
      script << "  #PJM -L \"node=\#{nodes_procs_threads_1}\"\n"
      script << "  #PJM --mpi \"proc=\#{nodes_procs_threads_2}\"\n"
    else
      script << "  #PJM -L \"node=\#{nodes_procs_1}\"\n"
      script << "  #PJM --mpi \"proc=\#{nodes_procs_2}\"\n"
    end
  end
  
  script << <<-YAML
  #PJM -L "elapse=\#{time_1}:\#{time_2}:00"
  #PJM -g \#{group}
  \#{mode}
  #PJM --mail-list \#{mail}
  #PJM -m \#{mail_option}
  #PJM \#{stat}
  #PJM --spath \#{stat_file_name}
  #PJM -x PJM_LLIO_GFSCACHE=\#{gfscache}
YAML
  script << "  set -e\n" unless app_name == "OpenFOAM"

  if rsc_group == "single" && enable_threads
    script << "  export OMP_NUM_THREADS=\#{threads}\n"
  elsif rsc_group != "single" && enable_threads
    script << "  export OMP_NUM_THREADS=\#{nodes_procs_threads_3}\n"
  end

  check = <<-YAML
  oc_assert(@time_1.to_i != 0 || @time_2.to_i != 0, "Time is too short.")
  message = "Exceeded Time (\#{@time_1}:\#{@time_2}:00)."
  oc_assert((@rsc_group != "small"      || @time_1.to_i != 72) || @time_2.to_i <= 0, message)
  oc_assert((@rsc_group != "large"      || @time_1.to_i != 24) || @time_2.to_i <= 0, message)
  oc_assert((@rsc_group != "f-pt"       || @time_1.to_i != 24) || @time_2.to_i <= 0, message)
  oc_assert((@rsc_group != "spot-small" || @time_1.to_i !=  4) || @time_2.to_i <= 0, message)
  oc_assert((@rsc_group != "spot-large" || @time_1.to_i !=  4) || @time_2.to_i <= 0, message)
YAML

  if rsc_group == "single" && enable_threads
    # Not required
  elsif rsc_group != "single" && enable_threads
    check << <<-YAML
  nodes   = @nodes_procs_threads_1.to_i
  procs   = @nodes_procs_threads_2.to_i
  threads = @nodes_procs_threads_3.to_i
  oc_assert(nodes * 48 >= procs * threads, 'The condition "nodes * 48 >= procs * threads" is not met.')
YAML
  elsif rsc_group != "single" && !enable_threads
    check << <<-YAML
  nodes   = @nodes_procs_1.to_i
  procs   = @nodes_procs_2.to_i
  oc_assert(nodes * 48 >= procs, 'The condition "nodes * 48 >= procs" is not met.')
YAML
  end
  
  return form.chomp, header(check_script_content, app_name).chomp, script.chomp, check.chomp, submit.chomp
end

def output_options(options, value)
  form = ""
  if options[0].is_a?(Array)
    options.each do |v|
      form << "      - ["
      form << v.each_with_index.map { |i, index| index >= 2 ? i : "\"#{i}\"" }.join(", ")
      form << "]\n"
    end
    form << (value == nil ? "    value: \"#{options[0][0]}\"" : "    value: \"#{value}\"")
  else
    options.each do |v|
      form << "      - [\"#{v}\", \"#{v}\"]\n"
    end
    form << (value == nil ? "    value: \"#{options[0]}\"" : "    value: \"#{value}\"")
  end

  return form
end

def text(key, label, value = nil, help = nil, required = false, indent = nil)
  form = <<-YAML
  #{key}:
    widget: text
    required: #{required ? "true" : "false"}
YAML
  form << "    label:  #{label}\n"  if label
  form << "    value:  #{value}\n"  if value
  form << "    help:   #{help}\n"   if help
  form << "    indent: #{indent}\n" if indent

  return form
end

def select(key, label, options, value = nil, help = nil, required = true, indent = nil)
  form = <<-YAML
  #{key}:
    widget: select
    required: #{required ? "true" : "false"}
    options:
#{output_options(options, value)}
YAML
  form << "    label:  #{label}\n"  if label
  form << "    value:  #{value}\n"  if value
  form << "    help:   #{help}\n"   if help
  form << "    indent: #{indent}\n" if indent

  return form
end

def radio(key, label, options, value = nil, help = nil, required = true, indent = nil)
  form = <<-YAML
  #{key}:
    widget: radio
    direction: horizontal
    required: #{required ? "true" : "false"}
    options:
#{output_options(options, value)}
YAML
  form << "    label:  #{label}\n"  if label
  form << "    value:  #{value}\n"  if value
  form << "    help:   #{help}\n"   if help
  form << "    indent: #{indent}\n" if indent

  return form
end

def checkbox(key, label, options, value = nil, help = nil, required = true, indent = nil)
  form = <<-YAML
  #{key}:
    widget: checkbox
    direction: horizontal
    required: #{required ? "true" : "false"}
    options:
#{output_options(options, value)}
YAML
  form << "    label:  #{label}\n"  if label
  form << "    value:  #{value}\n"  if value
  form << "    help:   #{help}\n"   if help
  form << "    indent: #{indent}\n" if indent

  return form
end

def path(key, label, help = nil, required = true, indent = nil, show_files = true)
  form = <<-YAML
  #{key}:
    widget: path
    value: #{default_dir()}
    show_files: #{show_files ? "true" : "false"}
    required: #{required ? "true" : "false"}
    #{favorites()}
YAML
  form << "    label:  #{label}\n"      if label
  form << "    help:   #{help}\n"       if help
  form << "    indent: #{indent}\n"     if indent

  return form
end

def working_dir(required)
  <<-YAML
  working_dir:
    widget: path
    label: Working directory
    value: #{default_dir()}
    show_files: false
    required: #{required}
    #{favorites()}
YAML
end

def exec_file(binaries, value = nil, widget = "select")
  if widget == "select"
    select("exec_file", "Executable file", binaries, value)
  else
    radio("exec_file", "Executable file", binaries, value)
  end
end

def input_file(required)
  path("input_file", "Input file", nil, required)
end

def llio(target)
  form = <<-YAML
  llio:
    label: LLIO target
    widget: radio
    direction: horizontal
    value: "(None)"
    help: To reduce IO load, the targets are transferred to the cache area. Enabling this feature is recommended when using more than 7,000 nodes or 28,000 processes <a href=\"https://www.fugaku.r-ccs.riken.jp/doc_root/en/user_guides/use_latest/LayeredStorageAndLLIO/index.html\">More info</a>.
    options:
      - ["(None)", "", disable-llio_comment, disable-llio_exec_file_transfer, disable-llio_file_transfer, disable-llio_dir_transfer ]
YAML
  if target == "file"
    form << "      - [\"Input file\", \"\", hide-llio_comment, hide-llio_exec_file_transfer, hide-llio_file_transfer, disable-llio_dir_transfer ]\n"
    form << "      - [\"Directory where input file exists\", \"\", hide-llio_comment, hide-llio_exec_file_transfer, disable-llio_file_transfer, hide-llio_dir_transfer ]\n"
  elsif target == "directory"
    form << "      - [\"Working directory\", \"\", hide-llio_comment, hide-llio_exec_file_transfer, disable-llio_file_transfer, hide-llio_dir_transfer]\n"
  end
  
  form += <<-YAML
  llio_comment:
    widget: text
    value: '\\n# LLIO transfer'

  llio_exec_file_transfer:
    widget: text
    value:  "/usr/bin/llio_transfer"

  llio_file_transfer:
    widget: text
    value:  "/usr/bin/llio_transfer"

  llio_dir_transfer:
    widget: text
    value: "/home/system/tool/dir_transfer"
YAML

  return form
end
