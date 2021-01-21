require 'line/bot'
require 'open_weather'
require 'time'
require 'date'

class KamigoController < ApplicationController
  protect_from_forgery with: :null_session

  def webhook
    ##
    # 離開群組
    reply_text = leave(channel_id, received_text)

  	# 學說話
  	reply_text = learn(channel_id, received_text) if reply_text.nil?

    # 關鍵字回覆
    reply_text = keyword_reply(channel_id, received_text) if reply_text.nil?

    # 說早安
    reply_text = morning(channel_id, received_text) if reply_text.nil?

    # 汐止天氣
    reply_text = Xizhi(channel_id, received_text) if reply_text.nil?

    # 年薪181萬一年可以買
    reply_text = price(channel_id, received_text) if reply_text.nil?

    # 推齊
    reply_text = echo2(channel_id, received_text) if reply_text.nil?

    # 記錄對話
    save_to_received(channel_id, received_text)
    save_to_reply(channel_id, reply_text)

    # 傳送訊息到 line
    response = reply_to_line(reply_text)
    
    # 回應 200
    head :ok
  end 

##################################################

  # 離開群組
  def leave(channel_id, received_text)
    #如果開頭不是 黑皮狗離開群組 就跳出
    return nil unless received_text[0..6] == '黑皮狗離開群組'
    # 傳送訊息
    response = line.leave_room(channel_id)
    response = line.leave_group(channel_id)
  end


  # 學說話
  def learn(channel_id, received_text)
    #如果開頭不是 黑皮狗; 就跳出
    return nil unless received_text[0..3] == '黑皮狗;'

    received_text = received_text[4..-1]
    semicolon_index = received_text.index(';')

    # 找不到分號就跳出
    return nil if semicolon_index.nil?

    keyword = received_text[0..semicolon_index-1]
    message = received_text[semicolon_index+1..-1]

    KeywordMapping.create(channel_id: channel_id, keyword: keyword, message: message)
    '已儲存指令～'
  end

  # 關鍵字回覆
  def keyword_reply(channel_id, received_text)
    message = KeywordMapping.where(channel_id: channel_id, keyword: received_text).last&.message
    return message unless message.nil?
    KeywordMapping.where(keyword: received_text).last&.message
  end

  # 推齊
  def echo2(channel_id, received_text)
    # 如果在 channel_id 最近沒人講過 received_text，卡米狗就不回應
    recent_received_texts = Received.where(channel_id: channel_id).last(5)&.pluck(:text)
    return nil unless received_text.in? recent_received_texts
    
    # 如果在 channel_id 卡米狗上一句回應是 received_text，卡米狗就不回應
    last_reply_text = Reply.where(channel_id: channel_id).last&.text
    return nil if last_reply_text == received_text

    received_text
  end

  # 說早安
  def morning(channel_id, received_text)
    #如果開頭不是 早安 就跳出
    return nil unless received_text[0..1] == '早安'
    '早安早安～(´・ω・`)'
  end

  # 汐止天氣
  def Xizhi(channel_id, received_text)
    #如果開頭不是 汐止天氣 就跳出
    return nil unless received_text[0..3] == '汐止天氣'

    # 取得天氣資訊
    options = { units: "metric", APPID: "419bd88fe3f4c88ded08d6dcfaaebfc3", lang: "zh_tw" }
    weather = OpenWeather::Current.city("Xizhi, TW", options)
    
    b = weather['weather'][0]['description'] #天氣
    c = weather['main']['temp'] #溫度
    d = weather['main']['humidity'] #濕度
    e = weather['name'] #地區
    e = "汐止"
    f = weather['wind']['speed'] #風速
    dt = Time.at(weather['dt']).to_datetime

    "《#{e}》\n天氣:#{b}\n溫度:#{c}\n濕度:#{d}\n風速:#{f}\n資料時間:#{dt}"
  end

  # 年薪181萬一年可以買
  def price(channel_id, received_text)
    #如果開頭不是 '$ ' 就跳出
    return nil unless received_text[0..1] == '$ '
    
    input_price = received_text[2..-1].to_i
    output_price = (1810000/input_price)

    "陳克軒一年可以買 #{output_price} 個"
  end

##################################################

  # 頻道 ID
  def channel_id
    source = params['events'][0]['source']
    return source['groupId'] unless source['groupId'].nil?
    return source['roomId'] unless source['roomId'].nil?
    source['userId']
  end

  # 儲存對話
  def save_to_received(channel_id, received_text)
    return if received_text.nil?
    Received.create(channel_id: channel_id, text: received_text)
  end

  # 儲存回應
  def save_to_reply(channel_id, reply_text)
    return if reply_text.nil?
    Reply.create(channel_id: channel_id, text: reply_text)
  end

##################################################

  # 取得對方說的話
  def received_text
    message = params['events'][0]['message']
    message['text'] unless message.nil?
  end

  # 傳送訊息到 line
  def reply_to_line(reply_text)
  	return nil if reply_text.nil?

    # 取得 reply token
    reply_token = params['events'][0]['replyToken']

    # 設定回覆訊息
    message = {
      type: 'text',
      text: reply_text
    } 

    # 傳送訊息
    response = line.reply_message(reply_token, message)
  end

  # Line Bot API 物件初始化
  def line
    return @line unless @line.nil?
    @line = Line::Bot::Client.new { |config|
      config.channel_secret = '918f82cd001be092d789f3aa53355490'
      config.channel_token = 'kwLvxvGXa5O3P4lHEJkhZ/mWyfDr8FssxxTNmGmcNo3coHGK0ETiZPAEURgEIwwEzyvAQoSU2VbUZNan950v4Yp6ylhSmw5PSWzLdWIx60RSWw0iZrWs2CkPAzNF9md4r5s2zbVML7RdOI8uN9dz/wdB04t89/1O/w1cDnyilFU='
    }
  end
end