package service

// WSType defines the WebSocket message type for the relay protocol.
type WSType string

const (
	WSTypeRegister          WSType = "register"
	WSTypeChallenge         WSType = "challenge"
	WSTypeChallengeResponse WSType = "challengeResponse"
	WSTypeRegistered        WSType = "registered"
	WSTypeSessionInit       WSType = "session-init"
	WSTypeSessionAck        WSType = "session-ack"
	WSTypeSessionEnd        WSType = "session-end"
	WSTypeRPC               WSType = "rpc"
	WSTypeResponse          WSType = "response"
	WSTypeEvent             WSType = "event"
	WSTypeError             WSType = "error"
)

// WSRole defines the registering WebSocket client role.
type WSRole string

const (
	WSRoleClient  WSRole = "client"
	WSRoleMachine WSRole = "machine"
)
