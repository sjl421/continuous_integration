#!/bin/bash

# Get the directory of this script.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PACKAGE="--all"
DEPENDENCIES=""
COMPILER="gcc"
RUN_TESTS=true
RUN_CPPCHECK=true

# Download / update dependencies.
for i in "$@"
do
case $i in
    -p=*|--packages=*)
    PACKAGES="${i#*=}"
    ;;
    -d=*|--dependencies=*)
    DEPENDENCIES="${i#*=}"
    ;;
    -c=*|--compiler=*)
    COMPILER="${i#*=}"
    ;;
    -t|--no_tests)
    RUN_TESTS=false
    ;;
    -n|--no_cppcheck)
    RUN_CPPCHECK=false
    ;;
    *)
       echo "Usage: run_build [{-d|--dependencies}=dependency_github_url.git]"
       echo "  [{-p|--packages}=packages]"
       echo "  [{--compiler}=gcc/clang]"
       echo "  [{-t|--no_tests} skip gtest execution]"
       echo "  [{-c|--no_cppcheck} skip cppcheck execution]"
    ;;
esac
done
echo "Parameters:"
echo "-----------------------------"
echo "Packages: ${PACKAGES}"
echo "Dependencies: ${DEPENDENCIES}"
echo "Execute integration tests: ${RUN_TESTS}"
echo "Run cppcheck: ${RUN_CPPCHECK}"
echo "-----------------------------"

echo "Compilers:"
echo "-----------------------------"
if [ "$COMPILER" == "gcc" ]
then
gcc -v
g++ -v
export CC=gcc
export CXX=g++
fi
if [ "$COMPILER" == "clang" ]
then
clang -v
export CC=clang
export CXX=clang
fi
echo "-----------------------------"

DEPS=src/dependencies

CATKIN_SIMPLE_URL=git@github.com:catkin/catkin_simple.git

DEPENDENCIES="${DEPENDENCIES} ${CATKIN_SIMPLE_URL}"

# Prepare cppcheck ignore list. We want to skip dependencies.
CPPCHECK_PARAMS="src --xml --enable=missingInclude,performance,style,portability,information -j8 -ibuild -i$DEPS"

mkdir -p $WORKSPACE/$DEPS && cd $WORKSPACE/$DEPS
for dependency in ${DEPENDENCIES}
do
    foldername_w_ext=${dependency##*/}
    foldername=${foldername_w_ext%.*}
    if [ -d $foldername ]; then
      echo Package "$foldername" exists, running git pull and git submodule update --recursive on "$dependency"
      cd "$foldername" && git pull && git submodule update --recursive && cd ..
    else
      echo Package "$foldername" does not exists, running git clone "$dependency" --recursive
      git clone "$dependency" --recursive
    fi
done
cd $WORKSPACE

echo -e "\nExecuting Jenkins independent refetch:"
echo "-----------------------------"
#FIX(Jenkins): Refetch the rep as it is not reliably done by Jenkins!
if [ -n "${sha1}" ]; then
	REP=$(find . -maxdepth 3 -type d -name .git -a \( -path "./$DEPS/*" -prune -o -print -quit \) )
	if [ -n "${REP}" ]; then
		REP=$(dirname "${REP}")
		echo "Refetching in ${REP} and checking out ${sha1} :"
		(cd "${REP}" && git fetch origin && git checkout "${sha1}");
	else
		echo "ERROR: Could not find repository to run Jenkins independent refetch."
	fi
else
	echo "SKIPPING: Variable sha1 not set or empty!"
fi
echo "-----------------------------"


#Now run the build.
if $DIR/run_build_catkin_or_rosbuild ${RUN_TESTS} ${COMPILER} ${PACKAGES}; then
  echo "Running cppcheck $CPPCHECK_PARAMS ..."
  # Run cppcheck excluding dependencies.
  cd $WORKSPACE
  if $RUN_CPPCHECK; then
    rm -f cppcheck-result.xml
    cppcheck $CPPCHECK_PARAMS 2> cppcheck-result.xml
  fi
else
 exit 1
fi


