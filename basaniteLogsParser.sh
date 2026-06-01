


One of the root causes of Jira failure can be the unavailability of the network-accessible NAS drive. Neither Jira nor the underlying Catalina Tomcat service properly recognizes or verifies the availability of the shared drive.

When the shared drive becomes unavailable, one of the secondary symptoms that can help identify the issue is a large number of errors related to unavailable email Velocity templates. We can detect NAS failures long before Jira starts flooding the logs with secondary errors.

To address this, we can implement a lightweight monitoring approach that periodically checks the availability of a permanent file on the shared drive, for example once per minute. This is a read-only file-level operation and does not use Jira or database resources.

If reading the file fails, the same script can write a message to a dedicated log file for analysis by Dynatrace. This enables early detection and prevention of cascading Jira failures caused by the unavailability of the shared drive, while also identifying the true root cause of the problem before large volumes of secondary errors appear in the logs.










One of the root causes of Jira failure can be the unavailability of the network-accessible NAS drive. Neither Jira nor the underlying Catalina Tomcat service properly recognizes or verifies the availability of the shared drive.

When the shared drive becomes unavailable, one of the secondary symptoms that can help identify the issue is a large number of errors related to unavailable email Velocity templates. We can detect NAS failures long before Jira starts flooding the logs with secondary errors.

To address this, we can implement a lightweight monitoring approach that periodically checks the availability of a permanent file on the shared drive, for example once per minute. This is a read-only file-level operation and does not use Jira or database resources.

If reading the file fails, the same script can write a message to a dedicated log file for analysis by Dynatrace. This enables early detection and prevention of cascading Jira failures caused by the unavailability of the shared drive, while also identifying the true root cause of the problem before large volumes of secondary errors appear in the logs.

There are two simple approaches available to accomplish this task:

1. Using a ScriptRunner Groovy script executed inside Jira. This approach allows centralized monitoring directly within the Jira application and can integrate with Jira logging and alerting mechanisms.

2. Running a lightweight Bash script under cron on each Jira node. This approach is fully independent from Jira itself and continues to work even when Jira services become unstable or partially unavailable.

The cron-based approach may provide earlier and more reliable detection because it operates outside of the Jira JVM and does not depend on application availability. Both solutions are low-overhead and can be implemented with minimal infrastructure changes.
