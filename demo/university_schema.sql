\set ON_ERROR_STOP 1

DROP TABLE IF EXISTS advisor CASCADE;
DROP TABLE IF EXISTS takes CASCADE;
DROP TABLE IF EXISTS teaches CASCADE;
DROP TABLE IF EXISTS section CASCADE;
DROP TABLE IF EXISTS course CASCADE;
DROP TABLE IF EXISTS student CASCADE;
DROP TABLE IF EXISTS instructor CASCADE;
DROP TABLE IF EXISTS department CASCADE;

CREATE TABLE department (
    dept_name varchar(20) PRIMARY KEY,
    building varchar(15),
    budget numeric(12,2) CHECK (budget > 0)
);

CREATE TABLE instructor (
    ID varchar(5) PRIMARY KEY,
    name varchar(20) NOT NULL,
    dept_name varchar(20),
    salary numeric(8,2) CHECK (salary > 29000),
    FOREIGN KEY (dept_name) REFERENCES department(dept_name)
);

CREATE TABLE student (
    ID varchar(5) PRIMARY KEY,
    name varchar(20) NOT NULL,
    dept_name varchar(20),
    tot_cred numeric(3,0) CHECK (tot_cred >= 0),
    FOREIGN KEY (dept_name) REFERENCES department(dept_name)
);

CREATE TABLE course (
    course_id varchar(8) PRIMARY KEY,
    title varchar(50),
    dept_name varchar(20),
    credits numeric(2,0) CHECK (credits > 0),
    FOREIGN KEY (dept_name) REFERENCES department(dept_name)
);

CREATE TABLE section (
    course_id varchar(8),
    sec_id varchar(8),
    semester varchar(6) CHECK (semester IN ('Fall', 'Winter', 'Spring', 'Summer')),
    year numeric(4,0) CHECK (year > 1701 AND year < 2100),
    building varchar(15),
    room_number varchar(7),
    time_slot_id varchar(4),
    PRIMARY KEY (course_id, sec_id, semester, year),
    FOREIGN KEY (course_id) REFERENCES course(course_id)
);

CREATE TABLE teaches (
    ID varchar(5),
    course_id varchar(8),
    sec_id varchar(8),
    semester varchar(6),
    year numeric(4,0),
    PRIMARY KEY (ID, course_id, sec_id, semester, year),
    FOREIGN KEY (course_id, sec_id, semester, year) REFERENCES section(course_id, sec_id, semester, year),
    FOREIGN KEY (ID) REFERENCES instructor(ID)
);

CREATE TABLE takes (
    ID varchar(5),
    course_id varchar(8),
    sec_id varchar(8),
    semester varchar(6),
    year numeric(4,0),
    grade varchar(2),
    PRIMARY KEY (ID, course_id, sec_id, semester, year),
    FOREIGN KEY (course_id, sec_id, semester, year) REFERENCES section(course_id, sec_id, semester, year),
    FOREIGN KEY (ID) REFERENCES student(ID)
);

CREATE TABLE advisor (
    s_ID varchar(5),
    i_ID varchar(5),
    PRIMARY KEY (s_ID),
    FOREIGN KEY (i_ID) REFERENCES instructor(ID),
    FOREIGN KEY (s_ID) REFERENCES student(ID)
);

INSERT INTO department VALUES
('Comp. Sci.', 'Taylor', 100000.00),
('Biology', 'Watson', 90000.00),
('Finance', 'Painter', 120000.00),
('Physics', 'Newton', 95000.00);

INSERT INTO instructor VALUES
('10101', 'Srinivasan', 'Comp. Sci.', 65000),
('22222', 'Einstein', 'Physics', 95000),
('32343', 'El Said', 'Finance', 60000),
('45565', 'Katz', 'Comp. Sci.', 75000),
('76766', 'Crick', 'Biology', 72000);

INSERT INTO student VALUES
('00128', 'Zhang', 'Comp. Sci.', 102),
('12345', 'Shankar', 'Comp. Sci.', 32),
('19991', 'Brandt', 'Finance', 80),
('23121', 'Chavez', 'Finance', 110),
('44553', 'Peltier', 'Physics', 56),
('54321', 'Williams', 'Comp. Sci.', 54),
('55739', 'Sanchez', 'Biology', 38),
('70557', 'Snow', 'Physics', 0),
('76543', 'Brown', 'Comp. Sci.', 58),
('76653', 'Aoi', 'Biology', 60);

INSERT INTO course VALUES
('CS-101', 'Intro. to Computer Science', 'Comp. Sci.', 4),
('CS-347', 'Database System Concepts', 'Comp. Sci.', 3),
('BIO-101', 'Intro. to Biology', 'Biology', 4),
('FIN-201', 'Investment Banking', 'Finance', 3),
('PHY-101', 'Physical Principles', 'Physics', 4);

INSERT INTO section VALUES
('CS-101', '1', 'Fall', 2026, 'Taylor', '101', 'A'),
('CS-347', '1', 'Fall', 2026, 'Taylor', '3128', 'B'),
('BIO-101', '1', 'Fall', 2026, 'Watson', '120', 'C'),
('FIN-201', '1', 'Fall', 2026, 'Painter', '201', 'D'),
('PHY-101', '1', 'Fall', 2026, 'Newton', '100', 'E');

INSERT INTO teaches VALUES
('10101', 'CS-101', '1', 'Fall', 2026),
('45565', 'CS-347', '1', 'Fall', 2026),
('76766', 'BIO-101', '1', 'Fall', 2026),
('32343', 'FIN-201', '1', 'Fall', 2026),
('22222', 'PHY-101', '1', 'Fall', 2026);

INSERT INTO advisor VALUES
('00128', '10101'),
('12345', '45565'),
('55739', '76766'),
('19991', '32343'),
('44553', '22222');
