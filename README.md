#### Description:

This is the Salesforce.com Visualforce UI code for a simple Attendance Management system where:

1. A teacher can view/mark attendance of all enrolled students in a subject that the teacher teaches.

2. A student can view his attendance in a subject that he is enrolled in.

This was coded as part of an interview assignment.

#### Given Requirements:

1. The data model/schema is provided on the Saleforce org as:

   ![Schema](schema.JPG?raw=true)

2. The UI mockup is provided as:

   ![Schema](uiMockup.JPG?raw=true)
   Note: Based on attendace percentage, the "Status" column displays a red cross, yellow tick or green tick.

#### Implementation:

- I have implemented a visualforce page and a controller, for the management of attendance as specified.
- A custom button can be added on the contact detail page called "Manage Attendance", which opens up the implemented visualforce page.
