package main

import "github.com/gin-gonic/gin"

type App struct {
	Router      *gin.Engine
	AuthCleanup func()
}
