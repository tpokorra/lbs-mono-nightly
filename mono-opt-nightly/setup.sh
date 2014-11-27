#!/bin/bash

Failed=0

function buildTarBall {
  giturl=$1
  branch=$2
  git clone $giturl work
  cd work
  if [[ "$branch" != "master" ]]
  then
    git checkout --track remotes/origin/$branch
  fi
  echo "current revision of git $giturl $branch: " `git rev-parse HEAD`
  . /opt/mono/env.sh
  ./autogen.sh
  # see http://jenkins.mono-project.com/view/Packaging-Mono/job/build-source-tarball-mono/
  make get-monolite-latest
  make
  make dist
  status=$?
  if [ $status -ne 0 ]
  then
    echo "LBSERROR: error during make dist"
    Failed=1
    return
  fi

  # get the version number from the generated tarball, eg. mono-3.6.1.tar.bz2
  filename=`ls mono-*.tar.bz2`
  # cut off .bz2
  version=${filename%.*}
  # cut off .tar
  version=${version%.*}
  # cut off mono-
  tarballversion=${version#*-}
  version="$tarballversion.99"
  cd ..
  # adjust the spec file for correct version number
  sed -i "s/%define version.*/%define version $version/g" mono-opt-nightly*.spec
  sed -i "s/%define tarballversion.*/%define tarballversion $tarballversion/g" mono-opt-nightly*.spec

  if [[ ! `ls work/mono-*.tar.bz2` ]]
  then
    echo "LBSERROR: no tarball was created"
    Failed=1
    return
  fi
  cp work/mono-*.tar.bz2 ~/tarball/mono-$branch-nightly.tar.bz2
  mv work/mono-*.tar.bz2 ~/sources/mono-nightly.tar.bz2

  echo "DONE with building the tarball for " $branch
  echo "download at http://lbs.solidcharity.com/tarballs/tpokorra/mono/mono-$branch-nightly.tar.bz2"
}

mkdir ~/sources

# install the packages that are needed to build the tarball.
# those are different packages than in BuildRequires in the spec file
if [ -f /etc/redhat-release ] 
then
  yum install -y git-core automake autoconf libtool tar which gcc-c++ gettext mono-opt bzip2 make gcc bison bzip2
else
  apt-get install -y --force-yes git-core
  echo "LBSERROR: need to install required packages for building tarball, see CentOS"
fi

branch=$1
buildTarBall "https://github.com/mono/mono.git" $branch

if [ $Failed -eq 1 ]
then
  exit -1
fi
