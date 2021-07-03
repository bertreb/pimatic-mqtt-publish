module.exports = {
  title: "mqtt-publish device config schemas"
  MqttPublish: {
    title: "MqttPublish Device"
    type: "object"
    properties:
      brokerId:
        description: "The brokerId of the MQTT broker which can be set for each device. Use 'default' for default Broker"
        type: "string"
        default: "default"
      topic:
        description: "The topic for all variablesto publish to"
        type: "string"
      variables:
        description: "list of  variable to be published"
        format: "table"
        type: "array"
        default: []
        items:
          type: "object"
          properties:
            id:
              description: "The pimatic variable id"
              type: "string"
            name:
              description: "The published variable name"
              type: "string"
            topic:
              description: "The optional variable specific topic"
              type: "string"
              required: false
  }
}
