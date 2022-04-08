# Autoscaling configuration

The `genesis do env_name.yml config-autoscaler` addon allows you to:

* Create autoscaling policies using basic metric types:
  * CPU
  * Memory Used (MB)
  * Memory Used (%)
  * Response Time
  * Throughput (requests per second)
* Store them under `/policies` directory of the root of your deployment using `$org_name-$space_name-$app_name-as-policy.json` filename structure
* Apply them to a specific application running under your cf deployment
* Update or re-apply a specific policy

and it does that by:

* Logging you in to your cf deployment
* Querying for the available orgs/spaces under your cf deployment letting you select the desired one
* Querying for the available applications under the specified org/space letting you select the desired one

## Pros

* Allows you to create and apply policies without having to know the structure of a policy.xml file
* Avoids common typos that make the process tedious and time consuming
* Provides a solid starting point for identifying a basic set of available metrics that can be used for autoscaling
* stores everything by default under your deployment directory allowing you to push it to your repository which:
   * Allows you to review each applications scaling policy in place without having to query cf for it
   * Allows you to restore a policy

## Cons

* It doesn't allow you to use multiple metrics simultaneously
* It only allows for the specific metrics to be configured
* it doesn't make you an expert on policies

# Usage

```
genesis do env-name.yml config-autoscaler
```

Answer a series of questions:

* _Type the organization name your application resides on_
* _Type the space name your application resides on_
* _Would you like to connect to another org/space?_
* _Type the application name you would like to configure autoscaling for_
* _Type the minimum number of instances running at all times_
* _Type the maximum number of instances running at all times_
* _Choose the metric type used for autoscaling_
* _Type the threshold value at which your instances will scale up_
* _Type the threshold value at which your instances will scale down_
* _The policy file aleady exists. Overwrite it?_ (if a policy file for the specific org-space-app is already in place)
* _Type the autoscaler service name you would like to use_
* _The application is already bound to an Auto-Scaling service. Re-apply it?_ (if the application is already bound to a service)

# Demo - Creating a policy without having logged in to cf

![Creating a policy](/files/tty-first.gif)

# Demo - Updating a policy having logged in to cf first

![Updating a policy](/files/tty-second.gif)
