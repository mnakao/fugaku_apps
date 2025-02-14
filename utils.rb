EXCLUDED_GROUPS = ["f-op", "fugaku", "oss-adm"] # "Group names starting with "isv" are deleted in the code.

def favorites()
  groups = `groups`.split
  favorites = []

  unless groups.empty?
    groups.each do |g|
      next if g.start_with?("isv")

      ["/data", "/share", "/2ndfs"].each do |base|
        dir = File.join(base, g)
        favorites << "      - \"#{dir}\"\n" if File.directory?(dir)
      end
    end
  end

  return nil if favorites.empty?

  form = "favorites:\n"
  favorites.each { |fav| form += fav }
  return form
end

def default_dir()
  groups = `groups`.split
  groups.each do |group|
    next if group.start_with?("isv")    
    candidate_dir = File.join("/data", group)
    return candidate_dir if File.directory?(candidate_dir)
  end
  
  Dir.home
end

def header()
  <<-YAML
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
end

def submit()
  <<-BASH
  #!/bin/bash
  OC_SUBMIT_OPTIONS=\"--no-check-directory\"
BASH
end

def rsc_group(enable_threads)
  yaml = <<-YAML
  rsc_group:
    widget: radio
    direction: horizontal
    label: Resource group
    value: small
    options:
      - [ small, small, disable-llio_comment, disable-llio_exec_file_transfer, disable-llio_file_transfer, disable-llio_dir_transfer ]
YAML
  if !enable_threads
    yaml << '      - [ large, large, set-label-nodes_procs_1: "Nodes (385 - 12,288)", set-min-nodes_procs_1: 385, set-max-nodes_procs_1: 12288, set-min-nodes_procs_2: 385, set-max-nodes_procs_2: 589824, set-label-nodes_procs_2: "Procs (385 - 589,824)", set-label-time_1: Maximum hours (0 - 24), set-max-time_1: 24, enable-llio ]' + "\n"
  else
    yaml << '      - [ large, large, set-label-nodes_procs_threads_1: "Nodes (385 - 12,288)", set-min-nodes_procs_threads_1: 385, set-max-nodes_procs_threads_1: 12288, set-min-nodes_procs_threads_2: 385, set-max-nodes_procs_threads_2: 589824, set-label-nodes_procs_threads_2: "Procs (385 - 589,824)", set-label-time_1: Maximum hours (0 - 24), set-max-time_1: 24, enable-llio ]' + "\n"
  end
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
    min:   [   1,   385 ]
    max:   [ 384, 18432 ]
    step:  [   1,     1 ]
    label: [ "Nodes (1 - 384)", "Procs (1 - 18,432)" ]
    required: [ true, true ]
    help: "\\"Nodes x 48 >= Procs\\" and \\"Nodes >= Procs\\" must hold."
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
    help: "\\"Nodes x 48 >= Procs x Threads\\" and \\"Nodes >= Procs\\" must hold."
YAML
end

def fugaku_common(rsc_group, enable_threads = true)
  form = rsc_group == "small_and_large" ? rsc_group(enable_threads) : ""

  if rsc_group == "single_procs" && enable_threads
    form << threads()
  elsif rsc_group != "single_procs" && !enable_threads
    form << nodes_procs()
  elsif rsc_group != "single_procs" && enable_threads
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
    - [ 'Show advanced option', '', show-mode, show-stat, show-mail, show-mail_option ]

  mode:
    widget: radio
    label: Execution mode
    direction: horizontal
    indent: 1
    value: Normal
    options:
      - [Normal,    "#PJM -L \\"freq=2000,eco_state=0\\""]
      - [Boost,     "#PJM -L \\"freq=2200,eco_state=0\\""]
      - [Eco,       "#PJM -L \\"freq=2000,eco_state=2\\""]
      - [Boost-Eco, "#PJM -L \\"freq=2200,eco_state=2\\""]
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
YAML

  script = "  #!/bin/bash\n"
  if rsc_group == "small_and_large"
    script << "  #PJM -L \"rscgrp=\#{rsc_group}\"\n"
  elsif rsc_group == "small"
    script << "  #PJM -L \"rscgrp=small\"\n"
  end

  if rsc_group == "single_procs" && enable_threads
  elsif rsc_group != "single_procs" && !enable_threads
    script << "  #PJM -L \"node=\#{nodes_procs_1}\"\n"
    script << "  #PJM --mpi \"proc=\#{nodes_procs_2}\"\n"
  elsif rsc_group != "single_procs" && enable_threads
    script << "  #PJM -L \"node=\#{nodes_procs_threads_1}\"\n"
    script << "  #PJM --mpi \"proc=\#{nodes_procs_threads_2}\"\n"
  end
  
  script << <<-YAML
  #PJM -L "elapse=\#{time_1}:\#{time_2}:00"
  #PJM -g \#{group}
  \#{mode}
  #PJM --mail-list \#{mail}
  #PJM -m \#{mail_option}
  #PJM \#{stat}
  #PJM --spath \#{stat_file_name}
YAML

  if rsc_group == "single_procs" && enable_threads
    script << "  export OMP_NUM_THREADS=\#{threads}\n"
  elsif rsc_group != "single_procs" && enable_threads
    script << "  export OMP_NUM_THREADS=\#{nodes_procs_threads_3}\n"
  end

  check = <<-YAML
  if @time_1.to_i == 0 && @time_2.to_i == 0
    halt 500, "Time is too short."
  elsif ((@rsc_group == "small" && @time_1.to_i == 72) || (@rsc_group == "large" && @time_1.to_i == 24)) && @time_2.to_i > 0
    halt 500, "Exceeded Time (#{@time_1}:#{@time_2}:00)."
  end
  
  nodes   = @nodes_procs_threads_1.to_i
  procs   = @nodes_procs_threads_2.to_i
  threads = @nodes_procs_threads_3.to_i
  if nodes * 48 < procs * threads
    halt 500, 'The condition "nodes * 48 >= procs * threads" is not met.'
  elsif nodes > procs
    halt 500, 'procs is smaller than nodes.'
  end
YAML

  return form.chomp, header.chomp, script.chomp, check.chomp, submit.chomp
end

def text(key, label, required = false)
  form = <<-YAML
  #{key}:
    widget: text
    label: #{label}
YAML
  form << "    required: #{required}" if required

  return form
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
end

def select(key, label, options, value = nil, help = nil)
  form = <<-YAML
  #{key}:
    widget: select
    required: true
    label: #{label}
    options:
#{output_options(options, value)}
YAML
  form << "    help: #{help}\n" if help != nil

  return form
end

def radio(key, label, options, value = nil, help = nil)
  form = <<-YAML
  #{key}:
    widget: radio
    direction: horizontal
    required: true
    label: #{label}
    options:
#{output_options(options, value)}
YAML
  form << "    help: #{help}" if help != nil

  return form
end

def path(key, label, required)
  <<-YAML
  #{key}:
    widget: path
    label: #{label}
    value: ""
    required: #{required}
    #{favorites()}
YAML
end

def working_dir(required)
  <<-YAML
  working_dir:
    widget: path
    label: Working directory
    value: ""
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
  path("input_file", "Input file", required)
end

def llio(target)
  form = <<-YAML
  llio:
    label: LLIO target
    widget: radio
    direction: horizontal
    value: "(None)"
    help: Enable this setting when using more than 7,000 nodes or 28,000 processes. To reduce IO load, the targets are transferred to the cache area. \
          <a href=\"https://www.fugaku.r-ccs.riken.jp/doc_root/en/user_guides/use_latest/LayeredStorageAndLLIO/index.html\">More info</a>.
    options:
      - ["(None)", "", disable-llio_comment, disable-llio_exec_file_transfer, disable-llio_file_transfer, disable-llio_dir_transfer ]
YAML
  if target == "file"
    form << "      - [\"Only input file\", \"\", hide-llio_comment, hide-llio_exec_file_transfer, hide-llio_file_transfer, disable-llio_dir_transfer ]\n"
    form << "      - [\"Directory where input file exists\", \"\", hide-llio_comment, hide-llio_exec_file_transfer, disable-llio_file_transfer, hide-llio_dir_transfer ]\n"
  elsif target == "directory"
    form << "      - [\"Working directory\", \"\", hide-llio_comment, hide-llio_exec_file_transfer, disable-llio_file_transfer, hide-llio_dir_transfer]\n"
  end
  
  form += <<-YAML
  llio_comment:
    widget: text
    value: "# LLIO transfer"

  llio_exec_file_transfer:
    widget: text
    value: "/usr/bin/llio_transfer"

  llio_file_transfer:
    widget: text
    value: "/usr/bin/llio_transfer"

  llio_dir_transfer:
    widget: text
    value: "/home/system/tool/dir_transfer"
YAML

  return form
end
