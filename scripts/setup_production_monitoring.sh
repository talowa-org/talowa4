#!/bin/bash

# TALOWA Production Monitoring and Alerting Setup Script
# Comprehensive monitoring system for 100,000+ user messaging platform
# Usage: ./scripts/setup_production_monitoring.sh [environment]

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${1:-production}"
GCP_PROJECT="talowa"
GCP_REGION="us-central1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create monitoring infrastructure
setup_monitoring_infrastructure() {
    log_info "Setting up monitoring infrastructure..."
    
    cd "$PROJECT_ROOT"
    mkdir -p monitoring/{dashboards,alerts,metrics,logs}
    
    # Create BigQuery datasets for analytics
    bq mk --dataset --location=US "$GCP_PROJECT:messaging_analytics" 2>/dev/null || log_warning "Dataset may already exist"
    bq mk --dataset --location=US "$GCP_PROJECT:performance_metrics" 2>/dev/null || log_warning "Dataset may already exist"
    bq mk --dataset --location=US "$GCP_PROJECT:security_logs" 2>/dev/null || log_warning "Dataset may already exist"
    
    # Create Cloud Storage buckets for log archival
    gsutil mb -p "$GCP_PROJECT" -l "$GCP_REGION" gs://"$GCP_PROJECT"-messaging-logs 2>/dev/null || log_warning "Bucket may already exist"
    gsutil mb -p "$GCP_PROJECT" -l "$GCP_REGION" gs://"$GCP_PROJECT"-performance-data 2>/dev/null || log_warning "Bucket may already exist"
    
    log_success "Monitoring infrastructure created"
}

# Setup custom metrics
setup_custom_metrics() {
    log_info "Setting up custom metrics..."
    
    cat > monitoring/metrics/custom_metrics.js << 'EOF'
const { Monitoring } = require('@google-cloud/monitoring');
const client = new Monitoring.MetricServiceClient();

async function createCustomMetrics() {
  const projectPath = client.projectPath(process.env.GCP_PROJECT);
  
  const metrics = [
    // Messaging Metrics
    {
      type: 'custom.googleapis.com/messaging/active_connections',
      displayName: 'Active WebSocket Connections',
      description: 'Number of active WebSocket connections',
      metricKind: 'GAUGE',
      valueType: 'INT64',
      labels: [
        { key: 'region', valueType: 'STRING', description: 'Server region' },
        { key: 'server_instance', valueType: 'STRING', description: 'Server instance ID' }
      ]
    },
    {
      type: 'custom.googleapis.com/messaging/messages_per_second',
      displayName: 'Messages Per Second',
      description: 'Rate of messages being processed per second',
      metricKind: 'GAUGE',
      valueType: 'DOUBLE',
      labels: [
        { key: 'message_type', valueType: 'STRING', description: 'Type of message (text, image, voice, etc.)' },
        { key: 'region', valueType: 'STRING', description: 'Server region' }
      ]
    },
    {
      type: 'custom.googleapis.com/messaging/message_delivery_latency',
      displayName: 'Message Delivery Latency',
      description: 'Time taken to deliver messages in milliseconds',
      metricKind: 'GAUGE',
      valueType: 'DOUBLE',
      labels: [
        { key: 'message_type', valueType: 'STRING', description: 'Type of message' },
        { key: 'delivery_method', valueType: 'STRING', description: 'Direct or group message' }
      ]
    },
    {
      type: 'custom.googleapis.com/messaging/failed_message_deliveries',
      displayName: 'Failed Message Deliveries',
      description: 'Number of failed message deliveries',
      metricKind: 'CUMULATIVE',
      valueType: 'INT64',
      labels: [
        { key: 'failure_reason', valueType: 'STRING', description: 'Reason for delivery failure' },
        { key: 'message_type', valueType: 'STRING', description: 'Type of message' }
      ]
    },
    
    // Voice Calling Metrics
    {
      type: 'custom.googleapis.com/voice/active_calls',
      displayName: 'Active Voice Calls',
      description: 'Number of active voice calls',
      metricKind: 'GAUGE',
      valueType: 'INT64',
      labels: [
        { key: 'call_type', valueType: 'STRING', description: 'Direct or group call' },
        { key: 'region', valueType: 'STRING', description: 'Server region' }
      ]
    },
    {
      type: 'custom.googleapis.com/voice/call_setup_time',
      displayName: 'Voice Call Setup Time',
      description: 'Time taken to establish voice calls in milliseconds',
      metricKind: 'GAUGE',
      valueType: 'DOUBLE',
      labels: [
        { key: 'call_type', valueType: 'STRING', description: 'Direct or group call' },
        { key: 'network_type', valueType: 'STRING', description: 'Network connection type' }
      ]
    },
    {
      type: 'custom.googleapis.com/voice/call_quality_score',
      displayName: 'Voice Call Quality Score',
      description: 'Voice call quality score (0-1)',
      metricKind: 'GAUGE',
      valueType: 'DOUBLE',
      labels: [
        { key: 'quality_metric', valueType: 'STRING', description: 'Latency, jitter, or packet_loss' }
      ]
    },
    {
      type: 'custom.googleapis.com/voice/failed_calls',
      displayName: 'Failed Voice Calls',
      description: 'Number of failed voice call attempts',
      metricKind: 'CUMULATIVE',
      valueType: 'INT64',
      labels: [
        { key: 'failure_reason', valueType: 'STRING', description: 'Reason for call failure' }
      ]
    },
    
    // File Sharing Metrics
    {
      type: 'custom.googleapis.com/files/upload_throughput',
      displayName: 'File Upload Throughput',
      description: 'File upload throughput in MB/s',
      metricKind: 'GAUGE',
      valueType: 'DOUBLE',
      labels: [
        { key: 'file_type', valueType: 'STRING', description: 'Type of file being uploaded' },
        { key: 'file_size_category', valueType: 'STRING', description: 'Small, medium, or large file' }
      ]
    },
    {
      type: 'custom.googleapis.com/files/download_throughput',
      displayName: 'File Download Throughput',
      description: 'File download throughput in MB/s',
      metricKind: 'GAUGE',
      valueType: 'DOUBLE',
      labels: [
        { key: 'file_type', valueType: 'STRING', description: 'Type of file being downloaded' }
      ]
    },
    {
      type: 'custom.googleapis.com/files/virus_scan_results',
      displayName: 'File Virus Scan Results',
      description: 'Results of file virus scanning',
      metricKind: 'CUMULATIVE',
      valueType: 'INT64',
      labels: [
        { key: 'scan_result', valueType: 'STRING', description: 'Clean, infected, or error' }
      ]
    },
    
    // Security Metrics
    {
      type: 'custom.googleapis.com/security/authentication_failures',
      displayName: 'Authentication Failures',
      description: 'Number of authentication failures',
      metricKind: 'CUMULATIVE',
      valueType: 'INT64',
      labels: [
        { key: 'failure_type', valueType: 'STRING', description: 'Invalid credentials, expired token, etc.' },
        { key: 'user_agent', valueType: 'STRING', description: 'Client user agent' }
      ]
    },
    {
      type: 'custom.googleapis.com/security/rate_limit_violations',
      displayName: 'Rate Limit Violations',
      description: 'Number of rate limit violations',
      metricKind: 'CUMULATIVE',
      valueType: 'INT64',
      labels: [
        { key: 'endpoint', valueType: 'STRING', description: 'API endpoint' },
        { key: 'violation_type', valueType: 'STRING', description: 'Type of rate limit violated' }
      ]
    },
    {
      type: 'custom.googleapis.com/security/suspicious_activities',
      displayName: 'Suspicious Activities',
      description: 'Number of detected suspicious activities',
      metricKind: 'CUMULATIVE',
      valueType: 'INT64',
      labels: [
        { key: 'activity_type', valueType: 'STRING', description: 'Type of suspicious activity' },
        { key: 'severity', valueType: 'STRING', description: 'Low, medium, high, critical' }
      ]
    },
    
    // Performance Metrics
    {
      type: 'custom.googleapis.com/performance/memory_usage_percent',
      displayName: 'Memory Usage Percentage',
      description: 'Memory usage percentage of messaging services',
      metricKind: 'GAUGE',
      valueType: 'DOUBLE',
      labels: [
        { key: 'service', valueType: 'STRING', description: 'Service name' },
        { key: 'instance', valueType: 'STRING', description: 'Service instance' }
      ]
    },
    {
      type: 'custom.googleapis.com/performance/cpu_usage_percent',
      displayName: 'CPU Usage Percentage',
      description: 'CPU usage percentage of messaging services',
      metricKind: 'GAUGE',
      valueType: 'DOUBLE',
      labels: [
        { key: 'service', valueType: 'STRING', description: 'Service name' },
        { key: 'instance', valueType: 'STRING', description: 'Service instance' }
      ]
    },
    {
      type: 'custom.googleapis.com/performance/database_query_latency',
      displayName: 'Database Query Latency',
      description: 'Database query latency in milliseconds',
      metricKind: 'GAUGE',
      valueType: 'DOUBLE',
      labels: [
        { key: 'query_type', valueType: 'STRING', description: 'Type of database query' },
        { key: 'collection', valueType: 'STRING', description: 'Firestore collection' }
      ]
    },
    
    // Business Metrics
    {
      type: 'custom.googleapis.com/business/daily_active_users',
      displayName: 'Daily Active Users',
      description: 'Number of daily active users',
      metricKind: 'GAUGE',
      valueType: 'INT64',
      labels: [
        { key: 'user_type', valueType: 'STRING', description: 'Member, coordinator, admin' },
        { key: 'region', valueType: 'STRING', description: 'Geographic region' }
      ]
    },
    {
      type: 'custom.googleapis.com/business/emergency_broadcasts_sent',
      displayName: 'Emergency Broadcasts Sent',
      description: 'Number of emergency broadcasts sent',
      metricKind: 'CUMULATIVE',
      valueType: 'INT64',
      labels: [
        { key: 'priority', valueType: 'STRING', description: 'High, critical' },
        { key: 'target_area', valueType: 'STRING', description: 'Geographic target area' }
      ]
    },
    {
      type: 'custom.googleapis.com/business/anonymous_reports_submitted',
      displayName: 'Anonymous Reports Submitted',
      description: 'Number of anonymous reports submitted',
      metricKind: 'CUMULATIVE',
      valueType: 'INT64',
      labels: [
        { key: 'report_category', valueType: 'STRING', description: 'Category of report' }
      ]
    }
  ];
  
  for (const metric of metrics) {
    try {
      await client.createMetricDescriptor({
        name: projectPath,
        metricDescriptor: metric
      });
      console.log(`✅ Created metric: ${metric.type}`);
    } catch (error) {
      if (error.code === 6) { // ALREADY_EXISTS
        console.log(`ℹ️  Metric already exists: ${metric.type}`);
      } else {
        console.error(`❌ Error creating metric ${metric.type}:`, error.message);
      }
    }
  }
}

createCustomMetrics().catch(console.error);
EOF
    
    # Install dependencies and run custom metrics setup
    cd monitoring/metrics
    npm init -y >/dev/null 2>&1
    npm install @google-cloud/monitoring >/dev/null 2>&1
    GCP_PROJECT="$GCP_PROJECT" node custom_metrics.js
    
    log_success "Custom metrics configured"
}

# Setup alerting policies
setup_alerting_policies() {
    log_info "Setting up alerting policies..."
    
    cat > monitoring/alerts/messaging_alerts.yaml << 'EOF'
displayName: "TALOWA Messaging System Critical Alerts"
policies:
  # High Error Rate Alert
  - displayName: "High Error Rate - WebSocket Server"
    conditions:
      - displayName: "Error rate > 5% for 5 minutes"
        conditionThreshold:
          filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="talowa-websocket"'
          comparison: COMPARISON_GREATER_THAN
          thresholdValue: 0.05
          duration: 300s
          aggregations:
            - alignmentPeriod: 60s
              perSeriesAligner: ALIGN_RATE
              crossSeriesReducer: REDUCE_MEAN
    alertStrategy:
      autoClose: 86400s
    severity: CRITICAL
    
  # High Latency Alert
  - displayName: "High Message Delivery Latency"
    conditions:
      - displayName: "Message delivery > 3 seconds"
        conditionThreshold:
          filter: 'metric.type="custom.googleapis.com/messaging/message_delivery_latency"'
          comparison: COMPARISON_GREATER_THAN
          thresholdValue: 3000
          duration: 300s
          aggregations:
            - alignmentPeriod: 60s
              perSeriesAligner: ALIGN_MEAN
              crossSeriesReducer: REDUCE_MEAN
    severity: WARNING
    
  # Memory Usage Alert
  - displayName: "High Memory Usage"
    conditions:
      - displayName: "Memory usage > 85%"
        conditionThreshold:
          filter: 'metric.type="custom.googleapis.com/performance/memory_usage_percent"'
          comparison: COMPARISON_GREATER_THAN
          thresholdValue: 85
          duration: 300s
    severity: WARNING
    
  # Connection Overload Alert
  - displayName: "WebSocket Connection Overload"
    conditions:
      - displayName: "Active connections > 80,000"
        conditionThreshold:
          filter: 'metric.type="custom.googleapis.com/messaging/active_connections"'
          comparison: COMPARISON_GREATER_THAN
          thresholdValue: 80000
          duration: 60s
    severity: CRITICAL
    
  # Voice Call Quality Alert
  - displayName: "Poor Voice Call Quality"
    conditions:
      - displayName: "Call quality score < 0.6"
        conditionThreshold:
          filter: 'metric.type="custom.googleapis.com/voice/call_quality_score"'
          comparison: COMPARISON_LESS_THAN
          thresholdValue: 0.6
          duration: 300s
    severity: WARNING
    
  # Security Alert - Authentication Failures
  - displayName: "High Authentication Failure Rate"
    conditions:
      - displayName: "Auth failures > 100/minute"
        conditionThreshold:
          filter: 'metric.type="custom.googleapis.com/security/authentication_failures"'
          comparison: COMPARISON_GREATER_THAN
          thresholdValue: 100
          duration: 60s
          aggregations:
            - alignmentPeriod: 60s
              perSeriesAligner: ALIGN_RATE
    severity: CRITICAL
    
  # Database Performance Alert
  - displayName: "High Database Query Latency"
    conditions:
      - displayName: "Query latency > 1000ms"
        conditionThreshold:
          filter: 'metric.type="custom.googleapis.com/performance/database_query_latency"'
          comparison: COMPARISON_GREATER_THAN
          thresholdValue: 1000
          duration: 300s
    severity: WARNING
    
  # File Upload Issues
  - displayName: "High File Upload Failure Rate"
    conditions:
      - displayName: "Upload failures > 10%"
        conditionThreshold:
          filter: 'resource.type="cloud_storage_bucket" AND metric.type="storage.googleapis.com/api/request_count"'
          comparison: COMPARISON_GREATER_THAN
          thresholdValue: 0.1
          duration: 300s
    severity: WARNING
    
  # Emergency Broadcast Delivery Issues
  - displayName: "Emergency Broadcast Delivery Failure"
    conditions:
      - displayName: "Broadcast delivery rate < 95%"
        conditionThreshold:
          filter: 'metric.type="custom.googleapis.com/business/emergency_broadcasts_sent"'
          comparison: COMPARISON_LESS_THAN
          thresholdValue: 0.95
          duration: 60s
    severity: CRITICAL
    
  # TURN Server Connectivity
  - displayName: "TURN Server Connectivity Issues"
    conditions:
      - displayName: "TURN server response time > 500ms"
        conditionThreshold:
          filter: 'resource.type="k8s_container" AND resource.labels.container_name="turn-server"'
          comparison: COMPARISON_GREATER_THAN
          thresholdValue: 500
          duration: 300s
    severity: WARNING
EOF
    
    # Create notification channels
    cat > monitoring/alerts/notification_channels.yaml << 'EOF'
notification_channels:
  - type: "email"
    displayName: "TALOWA Admin Email"
    labels:
      email_address: "admin@talowa.org"
    enabled: true
    
  - type: "slack"
    displayName: "TALOWA Slack Channel"
    labels:
      channel_name: "#alerts"
      url: "${SLACK_WEBHOOK_URL}"
    enabled: true
    
  - type: "sms"
    displayName: "Emergency SMS"
    labels:
      number: "+919876543210"
    enabled: true
EOF
    
    # Apply alerting policies using gcloud
    gcloud alpha monitoring policies create --policy-from-file=monitoring/alerts/messaging_alerts.yaml --project="$GCP_PROJECT" || log_warning "Some alerting policies may already exist"
    
    log_success "Alerting policies configured"
}

# Setup monitoring dashboards
setup_monitoring_dashboards() {
    log_info "Setting up monitoring dashboards..."
    
    cat > monitoring/dashboards/messaging_overview.json << 'EOF'
{
  "displayName": "TALOWA Messaging System Overview",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Active WebSocket Connections",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/messaging/active_connections\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "Connections",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "widget": {
          "title": "Messages Per Second",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/messaging/messages_per_second\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "yAxis": {
              "label": "Messages/sec",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "yPos": 4,
        "widget": {
          "title": "Message Delivery Latency",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/messaging/message_delivery_latency\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "yAxis": {
              "label": "Latency (ms)",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "yPos": 4,
        "widget": {
          "title": "Active Voice Calls",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/voice/active_calls\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "yAxis": {
              "label": "Active Calls",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 12,
        "height": 4,
        "yPos": 8,
        "widget": {
          "title": "System Resource Usage",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/performance/memory_usage_percent\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                },
                "plotType": "LINE",
                "legendTemplate": "Memory Usage"
              },
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/performance/cpu_usage_percent\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                },
                "plotType": "LINE",
                "legendTemplate": "CPU Usage"
              }
            ],
            "yAxis": {
              "label": "Usage (%)",
              "scale": "LINEAR"
            }
          }
        }
      }
    ]
  }
}
EOF
    
    cat > monitoring/dashboards/security_dashboard.json << 'EOF'
{
  "displayName": "TALOWA Security Monitoring",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Authentication Failures",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/security/authentication_failures\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "yAxis": {
              "label": "Failures/min",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "widget": {
          "title": "Rate Limit Violations",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/security/rate_limit_violations\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                },
                "plotType": "LINE"
              }
            ],
            "yAxis": {
              "label": "Violations/min",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 12,
        "height": 4,
        "yPos": 4,
        "widget": {
          "title": "Suspicious Activities by Severity",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/security/suspicious_activities\" AND metric.labels.severity=\"critical\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                },
                "plotType": "STACKED_BAR",
                "legendTemplate": "Critical"
              },
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"custom.googleapis.com/security/suspicious_activities\" AND metric.labels.severity=\"high\"",
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                },
                "plotType": "STACKED_BAR",
                "legendTemplate": "High"
              }
            ],
            "yAxis": {
              "label": "Activities/5min",
              "scale": "LINEAR"
            }
          }
        }
      }
    ]
  }
}
EOF
    
    # Create dashboards using gcloud
    gcloud monitoring dashboards create --config-from-file=monitoring/dashboards/messaging_overview.json --project="$GCP_PROJECT" || log_warning "Dashboard may already exist"
    gcloud monitoring dashboards create --config-from-file=monitoring/dashboards/security_dashboard.json --project="$GCP_PROJECT" || log_warning "Dashboard may already exist"
    
    log_success "Monitoring dashboards created"
}

# Setup log aggregation and analysis
setup_log_aggregation() {
    log_info "Setting up log aggregation and analysis..."
    
    # Create log sinks for different types of logs
    gcloud logging sinks create talowa-messaging-errors \
        bigquery.googleapis.com/projects/"$GCP_PROJECT"/datasets/messaging_analytics/tables/error_logs \
        --log-filter='severity>=ERROR AND (resource.type="cloud_run_revision" OR resource.type="cloud_function" OR resource.type="k8s_container")' \
        --project "$GCP_PROJECT" 2>/dev/null || log_warning "Error log sink may already exist"
    
    gcloud logging sinks create talowa-security-events \
        bigquery.googleapis.com/projects/"$GCP_PROJECT"/datasets/security_logs/tables/security_events \
        --log-filter='protoPayload.methodName=~".*auth.*" OR jsonPayload.event_type=~".*security.*" OR textPayload=~".*suspicious.*"' \
        --project "$GCP_PROJECT" 2>/dev/null || log_warning "Security log sink may already exist"
    
    gcloud logging sinks create talowa-performance-logs \
        bigquery.googleapis.com/projects/"$GCP_PROJECT"/datasets/performance_metrics/tables/performance_logs \
        --log-filter='jsonPayload.latency>1000 OR jsonPayload.response_time>2000' \
        --project "$GCP_PROJECT" 2>/dev/null || log_warning "Performance log sink may already exist"
    
    # Create BigQuery tables for log analysis
    cat > monitoring/logs/create_log_tables.sql << 'EOF'
-- Error logs table
CREATE TABLE IF NOT EXISTS `messaging_analytics.error_logs` (
  timestamp TIMESTAMP,
  severity STRING,
  resource_type STRING,
  service_name STRING,
  error_message STRING,
  stack_trace STRING,
  user_id STRING,
  request_id STRING,
  labels STRUCT<
    environment STRING,
    version STRING,
    region STRING
  >
);

-- Security events table
CREATE TABLE IF NOT EXISTS `security_logs.security_events` (
  timestamp TIMESTAMP,
  event_type STRING,
  user_id STRING,
  ip_address STRING,
  user_agent STRING,
  resource_accessed STRING,
  action_taken STRING,
  success BOOLEAN,
  failure_reason STRING,
  risk_score FLOAT64,
  labels STRUCT<
    severity STRING,
    category STRING,
    source STRING
  >
);

-- Performance logs table
CREATE TABLE IF NOT EXISTS `performance_metrics.performance_logs` (
  timestamp TIMESTAMP,
  service_name STRING,
  endpoint STRING,
  method STRING,
  response_time_ms FLOAT64,
  latency_ms FLOAT64,
  memory_usage_mb FLOAT64,
  cpu_usage_percent FLOAT64,
  concurrent_users INT64,
  throughput_rps FLOAT64,
  labels STRUCT<
    region STRING,
    instance_id STRING,
    version STRING
  >
);
EOF
    
    # Execute BigQuery table creation
    bq query --use_legacy_sql=false --project_id="$GCP_PROJECT" < monitoring/logs/create_log_tables.sql
    
    log_success "Log aggregation configured"
}

# Setup automated reporting
setup_automated_reporting() {
    log_info "Setting up automated reporting..."
    
    cat > monitoring/reports/daily_report_query.sql << 'EOF'
-- Daily Messaging System Report
WITH daily_stats AS (
  SELECT
    DATE(timestamp) as report_date,
    COUNT(*) as total_messages,
    AVG(CAST(JSON_EXTRACT_SCALAR(jsonPayload, '$.latency_ms') AS FLOAT64)) as avg_latency_ms,
    COUNT(DISTINCT JSON_EXTRACT_SCALAR(jsonPayload, '$.user_id')) as active_users,
    SUM(CASE WHEN severity = 'ERROR' THEN 1 ELSE 0 END) as error_count
  FROM `messaging_analytics.performance_logs`
  WHERE DATE(timestamp) = CURRENT_DATE() - 1
  GROUP BY DATE(timestamp)
),
security_stats AS (
  SELECT
    DATE(timestamp) as report_date,
    COUNT(*) as security_events,
    COUNT(CASE WHEN success = false THEN 1 END) as failed_auth_attempts,
    AVG(risk_score) as avg_risk_score
  FROM `security_logs.security_events`
  WHERE DATE(timestamp) = CURRENT_DATE() - 1
  GROUP BY DATE(timestamp)
)
SELECT
  d.report_date,
  d.total_messages,
  d.avg_latency_ms,
  d.active_users,
  d.error_count,
  s.security_events,
  s.failed_auth_attempts,
  s.avg_risk_score,
  CASE 
    WHEN d.avg_latency_ms < 1000 AND d.error_count < 100 AND s.failed_auth_attempts < 50 THEN 'HEALTHY'
    WHEN d.avg_latency_ms < 2000 AND d.error_count < 500 AND s.failed_auth_attempts < 200 THEN 'WARNING'
    ELSE 'CRITICAL'
  END as system_health_status
FROM daily_stats d
LEFT JOIN security_stats s ON d.report_date = s.report_date;
EOF
    
    # Create Cloud Function for automated reporting
    cat > monitoring/reports/report_function.js << 'EOF'
const { BigQuery } = require('@google-cloud/bigquery');
const { Storage } = require('@google-cloud/storage');
const nodemailer = require('nodemailer');

const bigquery = new BigQuery();
const storage = new Storage();

exports.generateDailyReport = async (req, res) => {
  try {
    // Execute daily report query
    const query = `
      WITH daily_stats AS (
        SELECT
          DATE(timestamp) as report_date,
          COUNT(*) as total_messages,
          AVG(CAST(JSON_EXTRACT_SCALAR(jsonPayload, '$.latency_ms') AS FLOAT64)) as avg_latency_ms,
          COUNT(DISTINCT JSON_EXTRACT_SCALAR(jsonPayload, '$.user_id')) as active_users,
          SUM(CASE WHEN severity = 'ERROR' THEN 1 ELSE 0 END) as error_count
        FROM \`${process.env.GCP_PROJECT}.messaging_analytics.performance_logs\`
        WHERE DATE(timestamp) = CURRENT_DATE() - 1
        GROUP BY DATE(timestamp)
      ),
      security_stats AS (
        SELECT
          DATE(timestamp) as report_date,
          COUNT(*) as security_events,
          COUNT(CASE WHEN success = false THEN 1 END) as failed_auth_attempts,
          AVG(risk_score) as avg_risk_score
        FROM \`${process.env.GCP_PROJECT}.security_logs.security_events\`
        WHERE DATE(timestamp) = CURRENT_DATE() - 1
        GROUP BY DATE(timestamp)
      )
      SELECT
        d.report_date,
        d.total_messages,
        d.avg_latency_ms,
        d.active_users,
        d.error_count,
        s.security_events,
        s.failed_auth_attempts,
        s.avg_risk_score,
        CASE 
          WHEN d.avg_latency_ms < 1000 AND d.error_count < 100 AND s.failed_auth_attempts < 50 THEN 'HEALTHY'
          WHEN d.avg_latency_ms < 2000 AND d.error_count < 500 AND s.failed_auth_attempts < 200 THEN 'WARNING'
          ELSE 'CRITICAL'
        END as system_health_status
      FROM daily_stats d
      LEFT JOIN security_stats s ON d.report_date = s.report_date;
    `;
    
    const [rows] = await bigquery.query(query);
    
    if (rows.length === 0) {
      console.log('No data available for yesterday');
      res.status(200).send('No data available');
      return;
    }
    
    const reportData = rows[0];
    
    // Generate report content
    const reportContent = `
TALOWA Messaging System Daily Report
Date: ${reportData.report_date}
=====================================

📊 SYSTEM METRICS
- Total Messages: ${reportData.total_messages?.toLocaleString() || 'N/A'}
- Average Latency: ${reportData.avg_latency_ms?.toFixed(2) || 'N/A'} ms
- Active Users: ${reportData.active_users?.toLocaleString() || 'N/A'}
- Error Count: ${reportData.error_count || 0}

🔒 SECURITY METRICS
- Security Events: ${reportData.security_events || 0}
- Failed Auth Attempts: ${reportData.failed_auth_attempts || 0}
- Average Risk Score: ${reportData.avg_risk_score?.toFixed(2) || 'N/A'}

🏥 SYSTEM HEALTH: ${reportData.system_health_status}

${reportData.system_health_status === 'CRITICAL' ? '🚨 IMMEDIATE ATTENTION REQUIRED' : ''}
${reportData.system_health_status === 'WARNING' ? '⚠️ MONITORING RECOMMENDED' : ''}
${reportData.system_health_status === 'HEALTHY' ? '✅ SYSTEM OPERATING NORMALLY' : ''}

Generated at: ${new Date().toISOString()}
    `;
    
    // Save report to Cloud Storage
    const bucket = storage.bucket(`${process.env.GCP_PROJECT}-messaging-logs`);
    const fileName = `daily-reports/report-${reportData.report_date}.txt`;
    const file = bucket.file(fileName);
    
    await file.save(reportContent);
    
    // Send email report if configured
    if (process.env.SMTP_HOST && process.env.REPORT_EMAIL) {
      const transporter = nodemailer.createTransporter({
        host: process.env.SMTP_HOST,
        port: 587,
        secure: false,
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS
        }
      });
      
      await transporter.sendMail({
        from: process.env.SMTP_USER,
        to: process.env.REPORT_EMAIL,
        subject: `TALOWA Daily Report - ${reportData.report_date} - ${reportData.system_health_status}`,
        text: reportContent
      });
    }
    
    res.status(200).json({
      success: true,
      reportDate: reportData.report_date,
      systemHealth: reportData.system_health_status,
      reportLocation: `gs://${process.env.GCP_PROJECT}-messaging-logs/${fileName}`
    });
    
  } catch (error) {
    console.error('Error generating daily report:', error);
    res.status(500).json({ error: error.message });
  }
};
EOF
    
    log_success "Automated reporting configured"
}

# Setup health checks
setup_health_checks() {
    log_info "Setting up health checks..."
    
    cat > monitoring/health/health_check_service.js << 'EOF'
const express = require('express');
const { Firestore } = require('@google-cloud/firestore');
const Redis = require('redis');
const app = express();

const firestore = new Firestore();
const redis = Redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379'
});

// Health check endpoint
app.get('/health', async (req, res) => {
  const healthStatus = {
    timestamp: new Date().toISOString(),
    status: 'healthy',
    services: {},
    version: process.env.VERSION || '1.0.0'
  };
  
  try {
    // Check Firestore connectivity
    const firestoreStart = Date.now();
    await firestore.collection('health_check').doc('test').set({
      timestamp: new Date()
    });
    await firestore.collection('health_check').doc('test').delete();
    const firestoreLatency = Date.now() - firestoreStart;
    
    healthStatus.services.firestore = {
      status: 'healthy',
      latency_ms: firestoreLatency
    };
    
    // Check Redis connectivity
    const redisStart = Date.now();
    await redis.ping();
    const redisLatency = Date.now() - redisStart;
    
    healthStatus.services.redis = {
      status: 'healthy',
      latency_ms: redisLatency
    };
    
    // Check system resources
    const memoryUsage = process.memoryUsage();
    healthStatus.services.system = {
      status: 'healthy',
      memory: {
        used_mb: Math.round(memoryUsage.heapUsed / 1024 / 1024),
        total_mb: Math.round(memoryUsage.heapTotal / 1024 / 1024)
      },
      uptime_seconds: process.uptime()
    };
    
    // Overall health determination
    const allServicesHealthy = Object.values(healthStatus.services)
      .every(service => service.status === 'healthy');
    
    if (!allServicesHealthy) {
      healthStatus.status = 'degraded';
    }
    
    res.status(healthStatus.status === 'healthy' ? 200 : 503).json(healthStatus);
    
  } catch (error) {
    healthStatus.status = 'unhealthy';
    healthStatus.error = error.message;
    res.status(503).json(healthStatus);
  }
});

// Detailed health check
app.get('/health/detailed', async (req, res) => {
  const detailedHealth = {
    timestamp: new Date().toISOString(),
    services: {}
  };
  
  try {
    // WebSocket server health
    detailedHealth.services.websocket = await checkWebSocketHealth();
    
    // TURN server health
    detailedHealth.services.turn = await checkTurnServerHealth();
    
    // Database performance
    detailedHealth.services.database = await checkDatabasePerformance();
    
    // File storage health
    detailedHealth.services.storage = await checkStorageHealth();
    
    res.json(detailedHealth);
    
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

async function checkWebSocketHealth() {
  // Implementation for WebSocket health check
  return { status: 'healthy', active_connections: 0 };
}

async function checkTurnServerHealth() {
  // Implementation for TURN server health check
  return { status: 'healthy', active_sessions: 0 };
}

async function checkDatabasePerformance() {
  const start = Date.now();
  await firestore.collection('users').limit(1).get();
  const latency = Date.now() - start;
  
  return {
    status: latency < 100 ? 'healthy' : 'degraded',
    query_latency_ms: latency
  };
}

async function checkStorageHealth() {
  // Implementation for storage health check
  return { status: 'healthy', available_space_gb: 1000 };
}

const PORT = process.env.PORT || 8081;
app.listen(PORT, () => {
  console.log(`Health check service running on port ${PORT}`);
});
EOF
    
    log_success "Health checks configured"
}

# Main setup function
main() {
    log_info "Setting up comprehensive monitoring for TALOWA Messaging System ($ENVIRONMENT)"
    
    setup_monitoring_infrastructure
    setup_custom_metrics
    setup_alerting_policies
    setup_monitoring_dashboards
    setup_log_aggregation
    setup_automated_reporting
    setup_health_checks
    
    log_success "🎉 Monitoring and alerting system setup completed!"
    log_info "Dashboard URLs:"
    log_info "- Main Dashboard: https://console.cloud.google.com/monitoring/dashboards"
    log_info "- Logs Explorer: https://console.cloud.google.com/logs/query"
    log_info "- Alerting Policies: https://console.cloud.google.com/monitoring/alerting"
    log_info "- BigQuery Analytics: https://console.cloud.google.com/bigquery"
}

# Run main function
main "$@"