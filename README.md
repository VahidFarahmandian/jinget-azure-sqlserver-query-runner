One of the most important challenges related to SQL Server databases during the CI/CD pipelines is the execution of various queries on databases. With the help of Jinget Query Runner extension, you can easily run different types of queries on SQL Server databases.

#### Key Features of Jinget Query Runner

1. Ease of use
2. Run any kind of T-SQL queries
3. Log the request and response details in Elasticsearch
4. Auto commit the changes to the repository
5. Multi environment support

#### How to Use
1. Download the extension from marketplace and install it on your organization
2. Go to the desired pipeline and select the Jinget Query Runner task among the task lists
3. Specify query runner common inputs
![Jinget Query Runner Common Options](http://jinget.ir/wp-content/uploads/2023/06/1-1.png "Jinget Query Runner Common Options")

**Root Folder (Required):** This folder contains other functional folders such as To Be Executed and etc. This option mainly is set to $(System.DefaultWorkingDirectory) variable.

**Running Environment (Required):** Specifies the environment type. Note that based on the chosen environment, the folders used are different. For the staging environment, the 'To Be Executed' folder contains the scripts to be run. The 'Staging Results' folder contains the output of scripts that ran successfully. The 'Staging Errors' folder contains errors that occurred after the scripts were executed. The 'To Production' folder contains scripts that have been successfully executed, so they are automatically moved to this folder and ready for production execution. For a production environment, new scripts should be placed in the 'To Production' folder, the 'Production Results' folder contains the output of the scripts, the 'Production Errors' folder contains the errors that occurred while running the scripts, and the 'Production Executed' folder contains the scripts which have been successfully executed in the production environment.

**Result Retention(Days) (Required):** For how many days should the content in the folders related to query execution results(Staging Results and Production Results folders) be kept? If this option set to zero, then this option will be ignored.

4. Specify query runner Database Options
![Jinget Query Runner Database Options](http://jinget.ir/wp-content/uploads/2023/06/2-2.png "Jinget Query Runner Database Options")

**SQL Server Instance (Required):** The address of the SQL Server Instance that hosts the database

**SQL Server Authentication Type (Required):** Specifies the authentication method. If 'Windows Authentication' selected, then queries will be executed under the user context of the Agent Service Account.

**Database Name (Required):** The name of the database which we want to execute query against it. 

**Query Timeout (Required):** Specifies the number of seconds before the queries time out. The timeout must be an integer value between 1 and 65535. 

**Database login name:** Username used for 'SQL Authentication'.

**Database login password:** Password used for 'SQL Authentication'

5. Specify the Elasticsearch logging options
![Elasticsearch logging options](http://jinget.ir/wp-content/uploads/2023/06/3.png "Elasticsearch logging options")

You can ignore the Elasticsearch logging by unchecking the checkbox in this section.

**Elastic Url:** Url which Elasticsearch service is up and running.

**Elastic username:** Username used for login to the Elasticsearch

**Elastic password:** Password used for login to the Elasticsearch

**Index Name:** Specify the Index which logging data should stored insode it. By default data will be stored in the predefined index(jinget.query.runner)

6. Specify the Git Options
![Jinget Query Runner Git Options](http://jinget.ir/wp-content/uploads/2023/06/4.png "Jinget Query Runner Git Options")

Behind the scenes, Jinget Query Runner needs to put the results back into the repository after running the queries. For this purpose, this option can be used. You can ignore this option by unchecking the checkbox in this section.

**Destination branch name:** Preferably, this branch should be the same branch that caused the pipeline to run. However you can specify any other brnaches too