module.exports = (env) ->

  # Pimatic MQTT publish
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = require 'lodash'

  class MqttPublishPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>

      @deviceConfigDef = require('./device-config-schema.coffee')
      plugin = @

      @framework.deviceManager.registerDeviceClass 'MqttPublish',
        configDef: @deviceConfigDef.MqttPublish
        createCallback: (config, lastState) -> return new MqttPublish(plugin, config, lastState)


  class MqttPublish extends env.devices.Device

    constructor: (@plugin, @config, lastState) ->
      mqttPlugin = @plugin.framework.pluginManager.getPlugin('mqtt')
      assert(mqttPlugin)
      #assert(mqttPlugin.brokers[@config.brokerId])

      @mqttPlugin = @plugin.framework.pluginManager.getPlugin('mqtt')
      unless @plugin.framework.pluginManager.isActivated('mqtt') and @mqttPlugin?
        env.logger.debug "MQTT not found or not activated"
        return

      @id = @config.id
      @name = @config.name
      @topic = @config.topic
      @message = {}
      @pirOn = true

      @mqttClient = @mqttPlugin.brokers[@config.brokerId].client
      if @mqttClient?
        if @mqttClient.connected
          @onConnect()

        @mqttClient.on('connect', =>
          @onConnect()
        )
      else
        env.logger.debug "Mqtt broker client does not excist"

      @plugin.framework.variableManager.waitForInit()
      .then ()=>
        for variable in @config.variables
          _variable = @plugin.framework.variableManager.getVariableValue(variable.id)
          unless _variable?
            throw new Error("Variable '#{variable.id}' does not excist")
          @message[variable.name] = _variable ? 0
        env.logger.debug "Message: " + JSON.stringify(@message,null,2)


      @plugin.framework.on 'variableValueChanged', @variableChangedHandler = (variable, value) =>
        _var = _.find(@config.variables, (v)=> v.id is variable.name)
        if _var?
          env.logger.debug "MqttPublish Variable changed: id: " + variable.name + ", value: " + value
          @message[_var.name] = Number value


      @mqttClient.on 'message', @mqttMessageHandler = (topic, message) =>
        if topic.indexOf(@topic + "/pir") >= 0
          env.logger.debug "Message received, topic: " + topic + ", message: " + message
          if (Number message) == 1
            @pirOn = true
            @updater()
          else
            @pirOn = false

      @updater = () =>
        _message = JSON.stringify(@message)
        @mqttClient.publish(@topic, _message)
        env.logger.debug "Updater => message sent, topic: " + @topic+ ", message: " + _message + ", @pirOn: " + @pirOn
        if @pirOn is true
          @updateTimer = setTimeout(@updater,5000)
      @updater()

      super()

    onConnect: () ->
      if @topic
        @mqttClient.subscribe(@topic+"/pir")
        env.logger.debug "Subscribed to: " + @topic+"/pir"

      for variable in @config.variables
        _variable = @plugin.framework.variableManager.getVariableValue(variable.id)
        unless _variable?
          throw new Error("Variable '#{variable.id}' does not excist")
        @message[variable.name] = _variable ? 0
      env.logger.debug "Message: " + JSON.stringify(@message,null,2)

    destroy: () ->
      if @topic
        @mqttClient.unsubscribe(@topic)
      if @variableChangedHandler?
        @plugin.framework.removeListener('variableValueChanged', @variableChangedHandler)
      if @mqttMessageHandler?
        @mqttClient.removeListener('message', @mqttMessageHandler)
      if @updateTimer?
        clearTimeout(@updateTimer)
      super()


  myMqttPublishPlugin = new MqttPublishPlugin()
  return myMqttPublishPlugin
