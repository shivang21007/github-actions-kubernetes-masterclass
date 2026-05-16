package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/trainwithshubham/skillpulse/database"
	"github.com/trainwithshubham/skillpulse/models"
)

func GetDashboard(c *gin.Context) {
	var dash models.Dashboard

	for _, stmt := range []struct {
		q string
		d any
	}{
		{"SELECT COUNT(*) FROM skills", &dash.TotalSkills},
		{"SELECT COALESCE(SUM(hours), 0) FROM learning_logs", &dash.TotalHours},
		{"SELECT COUNT(*) FROM learning_logs", &dash.TotalLogs},
	} {
		if err := database.DB.QueryRow(stmt.q).Scan(stmt.d); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}

	err := database.DB.QueryRow(`
		SELECT s.name FROM skills s
		LEFT JOIN learning_logs l ON s.id = l.skill_id
		GROUP BY s.id, s.name
		ORDER BY COALESCE(SUM(l.hours), 0) DESC
		LIMIT 1
	`).Scan(&dash.TopSkill)
	if err != nil {
		dash.TopSkill = "N/A"
	}

	c.JSON(http.StatusOK, dash)
}

func HealthCheck(c *gin.Context) {
	err := database.DB.Ping()
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"status": "unhealthy", "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "healthy"})
}
