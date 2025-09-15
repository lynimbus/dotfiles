# QQ配置文件的路径
CONFIG_FILE="$HOME/.config/QQ/versions/config.json"

# 读取配置文件内容
CONFIG_CONTENT=$(cat "$CONFIG_FILE")

# 使用jq解析JSON，获取相关版本信息
BASE_VERSION=$(echo "$CONFIG_CONTENT" | jq -r '.baseVersion')
CUR_VERSION=$(echo "$CONFIG_CONTENT" | jq -r '.curVersion')

# 判断baseVersion和curVersion是否不一致
if [ "$BASE_VERSION" != "$CUR_VERSION" ]; then

  # 将当前curVersion添加到onErrorVersions
  NEW_CONFIG=$(echo "$CONFIG_CONTENT" | jq --arg cur "$CUR_VERSION" '.onErrorVersions += [$cur]')

  # 将curVersion更改为baseVersion
  NEW_CONFIG=$(echo "$NEW_CONFIG" | jq --arg base "$BASE_VERSION" '.curVersion = $base')

  # 将修改后的内容写回配置文件
  echo "$NEW_CONFIG" >"$CONFIG_FILE"
else
  exit 0
fi
