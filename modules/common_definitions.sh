if [ -z "$CI_MODULES" ]; then
  echo "CI_MODULES not set!" 2>&1
  exit 4
fi
if [ -z "$WORKSPACE" ]; then
  echo "WORKSPACE not set!" 2>&1
  exit 5
fi

if [ -z "$_COMMON_LOADED_" ]; then
  _COMMON_LOADED_=true

  ROS_VERSION=$(source $CI_MODULES/get_latest_ros_version.sh)
  
  # Source current ROS
  source /opt/ros/$ROS_VERSION/setup.sh
  
  # DEPS must be below src/ !
  DEPS=src/dependencies
  
  CATKIN_SIMPLE_URL=https://github.com/catkin/catkin_simple.git
  
  function fatal() {
    echo "ERROR: $@" >&2
    exit 1
  }
  function warning() {
    echo "WARNING: $@" >&2
  }
  
  WSTOOL_MERGE_REPLACE="wstool merge --confirm-all --merge-replace -t $WORKSPACE/$DEPS"
  function wstoolUpdateReplace () {
    wstool status -t $WORKSPACE/$DEPS
    wstool update --delete-changed-uris -t $WORKSPACE/$DEPS -j1 "$@"
  }
  WSTOOL_UPDATE_REPLACE="wstoolUpdateReplace"
fi
