public class AttendanceMgmtCtrl {
    public enum ContactType {Teacher,Student,None}
    public class Icon {
        public String name {get;set;}
        public String color {get;set;}
        public Icon(String name, String color){
            this.name = name;
            this.color = color;
        }
    }
    public class StudentAttendances {
        private Icon[] icons = new Icon[] {
            new Icon('approval','green'),
            new Icon('approval','yellow'),
            new Icon('reject','red')
        };
        public Contact student {get; set;}
        public List<Attendance__c> attendances {get; set;}
        private Integer percentage;
        public StudentAttendances(Contact student, List<Attendance__c> attendances, Integer percentage){
            this.student = student;
            this.attendances = attendances;
            this.percentage = percentage;
        }
        public Icon getIndicatorIcon(){
            if(percentage < 25){
                return icons[2];
            }
            if(percentage <= 75)
            	return icons[1];
            
            return icons[0];
        }
    }
    
    //private members
    private Contact currentContact;
    private ContactType conType;
    private Map<Id, StudentAttendances> studentAttendancesMap;
    private Attendance__c changedAttendance;
    
    
    //vf props
    public boolean isTeacher {get;set;}
    public List<Subject__c> subjects;
    public Id selectedSubject {get;set;}
    public List<Session__c> sessions;
    private List<Contact> students;
    public List<StudentAttendances> attendances;
    public Integer[] sessionIndices {get{
        Integer [] indices = new Integer[this.sessions.size()];
        for(Integer i=0;i<indices.size();i++) indices[i]=i;
        return indices; 
    }}
    
    public AttendanceMgmtCtrl(){
        loadContact();
        List<Subject__c> subjects = getSubjects();
        if(subjects.size()>0) selectedSubject = subjects[0].Id;
    }

    private void loadContact(){
        Id contactId = (Id) ApexPages.currentPage().getParameters().get('contactId');
        if(contactId != null){
        	currentContact = [select Id, Name, RecordType.Name from Contact where Id = :contactId];
            conType = (currentContact.RecordType.Name == 'Teacher') ? ContactType.Teacher :
                  	  (currentContact.RecordType.Name == 'Student') ? ContactType.Student :
                  	  ContactType.None;
        } else {
            conType = ContactType.None;
        }
        isTeacher = (conType == ContactType.Teacher);
    }
    
    public String getConType(){
        return conType.name();
    }

    //gets subjects associated with the current student or teacher
    public List<Subject__c> getSubjects(){
        if(this.subjects != null) return this.subjects;
        
        this.subjects = new List<Subject__c>();
        if(conType != ContactType.None){
            this.subjects = isTeacher ? getTaughtSubjects():getEnrolledSubjects();
        }
        return this.subjects;
    }
    
    //gets subjects taught by the current teacher
    private List<Subject__c> getTaughtSubjects(){
        return [select Name from Subject__c where Teacher__c =:currentContact.Id];
    }
    
    //gets subjects enrolled in by the current student
    private List<Subject__c> getEnrolledSubjects(){
        List<Subject__c> subjects = new List<Subject__c>();
        for(Enrollment__c e : [select Subject__r.Name from Enrollment__c where Student__c =:currentContact.Id]){
            subjects.add(e.Subject__r);
        }
        return subjects;
    }
    
    // gets Sessions for the selected subject, starting from the previous week up till 'today'
    public List<Session__c> getSessions() {
        if(this.sessions != null) return this.sessions;
        this.sessions = new List<Session__c>();
        if(!String.isEmpty(this.selectedSubject)) {
        	Date startDate = getStartDate();
			Date endDate = getEndDate();
            this.sessions = [select Session_Date__c from Session__c where Subject__c =:selectedSubject AND
        	Session_Date__c >= :startDate AND Session_Date__c <= :endDate order by Session_Date__c];
        }
        return this.sessions;
    }
    
    private Date getStartDate(){
        return Date.today().toStartofWeek().addDays(-7); //last week start
    }

    private Date getEndDate(){
        return Date.today();
    }
    
    /* gets all students enrolled in the selected subject, if current user is a teacher
    * or only the current user itself, if he is a student
    */
    private List<Contact> getStudents() {
        if(this.students != null) return this.students;
        this.students = new List<Contact>();
        if(!String.isEmpty(selectedSubject)) {
        	this.students = (isTeacher) ? getEnrolledStudents() : new List<Contact>{currentContact};
        }
        return this.students;
    }

    //gets all students enrolled in the selected subject
    private List<Contact> getEnrolledStudents() {
        List<Contact> students = new List<Contact>();
        List<Enrollment__c> enrollments = [select Student__r.Name from Enrollment__c where Subject__c =: selectedSubject
                                          Order By Student__r.Name];
        for(Enrollment__c e: enrollments){
            students.add(e.Student__r);
        }
        return students;
    }

    //gets a list of a wrapper class "StudentAttendances".
    //Each "StudentAttendances" object contains the student id, along with a list of all his attendances for the
    //sessions of the selected subject, and the attendance percentage
    public List<StudentAttendances> getAttendances() {
        if(this.attendances != null) return this.attendances;
        this.attendances = new List<StudentAttendances>();
        if(String.isEmpty(selectedSubject)) return this.attendances;

        List<Session__c> sessions = getSessions();
        List<Contact> students = getStudents();
        List<Attendance__c> existingAttendances = getExistingAttendances(sessions,students,selectedSubject);
        
        Map<Id,Map<Id,Attendance__c>>  existingStudentAttendancesMap = buildStudentAttendancesMap(existingAttendances);
        buildStudentAttendances(students,sessions,existingStudentAttendancesMap);
        return this.attendances;
    }
    
    private List<Attendance__c> getExistingAttendances(List<Session__c> sessions, List<Contact> students, Id subjectId) {
        return [select Enrollment__r.Student__c,Session__c,Status__c from Attendance__c
                where Enrollment__r.Subject__c=:subjectId AND
                Session__c in :sessions AND Enrollment__r.Student__c in:students];
    }
    
    private Map<Id,Map<Id,Attendance__c>> buildStudentAttendancesMap(List<Attendance__c> attendances) {
        Map<Id,Map<Id,Attendance__c>>  studentAttendancesMap = new Map<Id,Map<Id,Attendance__c>>();
        for(Attendance__c a: attendances){
            Map<Id,Attendance__c> sessionAttendanceMap = studentAttendancesMap.get(a.Enrollment__r.Student__c);
            if(sessionAttendanceMap == null) {
                sessionAttendanceMap = new Map<Id,Attendance__c>();
                studentAttendancesMap.put(a.Enrollment__r.Student__c,sessionAttendanceMap);
            }
            sessionAttendanceMap.put(a.Session__c,a);
        }
        return studentAttendancesMap;
    }
    
    private void buildStudentAttendances(List<Contact> students,  List<Session__c> sessions,
        Map<Id,Map<Id,Attendance__c>> existingStudentAttendancesMap){
        this.attendances = new List<StudentAttendances>();
        this.studentAttendancesMap = new Map<Id,StudentAttendances>();
        Map<Id, Integer> percentages = getAttendancePercentages(students);
        for(Contact student :students){
            Map<Id, Attendance__c> existingSessionAttendanceMap = new Map<Id, Attendance__c>();
            if(existingStudentAttendancesMap.containsKey(student.Id)){
                existingSessionAttendanceMap = existingStudentAttendancesMap.get(student.Id);
            }
            List<Attendance__c> studentAttendance = new List<Attendance__c>();
            for(Session__c session: sessions){
            	Attendance__c a = (existingSessionAttendanceMap.containsKey(session.Id)) ?
                    existingSessionAttendanceMap.get(session.Id) : getNewAttendanceInstance(student,session);
                studentAttendance.add(a);
            }
            StudentAttendances sa = new StudentAttendances(student,studentAttendance, percentages.get(student.Id));
            this.attendances.add(sa);
            this.studentAttendancesMap.put(student.Id,sa);
        }
    }
    
    //creates a map of student id to his attendance percentage
    //percentage is calculated based on number of sessions attended out of all sessions of the selected subject, up till 'today'
    private Map<Id, Integer> getAttendancePercentages(List<Contact> students){
        Map<Id, Integer> percentages = new Map<Id, Integer>();
        Integer totalSessions = [select count() from Session__c where Subject__c=:selectedSubject
                                AND Session_Date__c <= :Date.today()];
        
        Map<Id, Integer> attendanceCounts = new Map<Id, Integer>();
        AggregateResult[] results  = [select Enrollment__r.Student__c  studentId, count(Status__c) totalAttended 
            from Attendance__c where Status__c = 'Present' AND Enrollment__r.Student__c in:students 
            AND Session__r.Subject__c =:selectedSubject AND Session__r.Session_Date__c <= :Date.today()
        	group by Enrollment__r.Student__c];
        for(AggregateResult res: results){
            attendanceCounts.put((Id)res.get('studentId'),(Integer) res.get('totalAttended'));
        }
        for(Contact s: students){
            Integer totalAttended = attendanceCounts.containsKey(s.Id) ? attendanceCounts.get(s.Id) : 0;
            Integer perc = (totalSessions == 0) ? 100 : (Integer) Math.ceil((totalAttended*100.0)/totalSessions);
            percentages.put(s.Id,perc);
        }
        return percentages;
    }
    
    //creates a new instance of Attendance__c if there is no existing attendance record.
    private Attendance__c getNewAttendanceInstance(Contact student, Session__c session){
        return new Attendance__c(Enrollment__r = new Enrollment__c(Student__c=student.Id), Session__c=session.Id);
    }

    public void onSubjectChange() {
        resetAttendanceTable();       
    }
    
    //resets data about sessions, attendance etc. which is dependent on the selected subject
    //so that new data is fetched
    private void resetAttendanceTable(){
        this.sessions = null;
        this.students = null;
        this.attendances = null;
        this.studentAttendancesMap = null;
    }  

    private void setChangedAttendance(){
        Map<String,String> params = Apexpages.currentPage().getParameters();
        Integer sessionindex = Integer.valueOf(params.get('sessionIndex')) ;
        Id studentId = (Id)params.get('studentId');
        Attendance__c a = this.studentAttendancesMap.get(studentId).attendances[sessionindex];
        a.Status__c = params.get('attendanceStatus');
        changedAttendance = a;
    }
    private void saveAttendance(){
        Id studentId = changedAttendance.Enrollment__r.Student__c;
        if(changedAttendance.Id == null){ //new attendance instance
            Enrollment__c e = [select Id,Student__c from Enrollment__c where Student__c =:studentId AND Subject__c=:selectedSubject];
            changedAttendance.Enrollment__c = e.Id;
            changedAttendance.Enrollment__r = e;
        }
        upsert changedAttendance;
    }
    
    //add updated attendace object to the StudentAttendances list so that it is updated on UI
    private void updateStudentAttendancesMap(){
        Session__c session = new Session__c(Id=changedAttendance.Session__c);
        Contact student = new Contact(Id=changedAttendance.Enrollment__r.Student__c);
        List<Contact> changedStudents = new List<Contact>{student};
        
        Attendance__c updated = getExistingAttendances(new List<Session__c>{session},
                                   changedStudents, selectedSubject)[0];
        
        Integer index = -1;
        StudentAttendances sa = this.studentAttendancesMap.get(student.Id);
        //find attendance entry to update in list
        for(Attendance__c a: sa.attendances){
            index++;
            if(a.Session__c == changedAttendance.Session__c){
                break;
            }
        }
        sa.attendances.set(index, updated);
        Map<Id, Integer> percentages = getAttendancePercentages(changedStudents);
        sa.percentage = percentages.get(student.Id);
    }

    //When attendance status is changed, we only update that particular record in the database
    //and subsequently in our controller "state".
    //not re-fetching all data again
    public void onAttendanceChange(){
        setChangedAttendance();
		saveAttendance();
        updateStudentAttendancesMap();
    }
    
}