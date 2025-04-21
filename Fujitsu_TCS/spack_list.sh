. /vol0004/apps/oss/spack/share/spack/setup-env.sh
spack find --format '{name}@{version}/{hash:7}' platform=linux os=rhel8 target=a64fx | awk '{print $1}' > spack_list.txt

