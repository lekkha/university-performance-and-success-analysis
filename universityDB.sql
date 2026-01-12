CREATE DATABASE universitydb;
USE universitydb;

truncate table university;
select * from university;

LOAD DATA INFILE "D:/university.csv"
INTO TABLE university
CHARACTER SET utf8
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

select count(*) from university_ranking_year;

-- DATA CLEANING ---

-- 1. univ yr

-- Duplicates basis primary key univ yr and id 
Select university_id, year, count(*) 
from university_year
group by university_id, year
having count(*) > 1 ; 

-- Null / missing values in each cols 
Select count(pct_female_students)
from university_year
where pct_female_students IS NULL or pct_female_students = '';

-- Replace NULL values with the median or mean of the column to avoid skewing summary statistics.
set sql_safe_updates =0 ;
Update university_year
set pct_female_students = (select avg from (Select Avg(pct_female_students) as avg  from university_year) as t)
where pct_female_students is null or  pct_female_students = '';

-- Checking for outlier values
select avg(num_students) as stu , avg(student_staff_ratio) as sr, avg(pct_female_students) as sf, 
min(num_students) as ms ,  min(student_staff_ratio) as msr ,  min(pct_female_students) as msf,
max(num_students) as mas ,  max(student_staff_ratio) as masr ,  max(pct_female_students) as masf
from university_year;

select * 
from university_year
where num_students < 0 
or student_staff_ratio < 0
or pct_international_students not between 0 and 100 
or pct_female_students not between 0 and 100;

-- 2. Univ ranking yr 

set sql_safe_updates =0 ;
-- duplicates 
select university_id, ranking_criteria_id, year, count(*)
from university_ranking_year 
group by university_id, ranking_criteria_id, year
having count(*)>1;

-- missing vlaues
select count(score) / (select count(*) from university_ranking_year)
from university_ranking_year 
where score is null or score = '';

-- since % is too low thus removing values 
delete from university_ranking_year where score is null or score = ''; 

-- checking invlaid scores
SELECT MIN(score), MAX(score) FROM university_ranking_year;

-- 3. University 
SELECT id, COUNT(*) FROM university GROUP BY id HAVING COUNT(*) > 1;
SELECT university_name, COUNT(*) FROM university GROUP BY university_name HAVING COUNT(*) > 1;
SELECT university_name FROM university;

-- detecting non ASCII char in univ name by by using regex for non ascii char
SELECT university_name
FROM university
WHERE university_name REGEXP '[^ -~]';

-- correct univ name 
SELECT 
    CONVERT(BINARY CONVERT(university_name USING latin1) USING utf8mb4) AS fixed_name
FROM university
WHERE university_name = 'Pontifical Catholic University of ParanÃ¡';

UPDATE university
set university_name =  CONVERT(BINARY CONVERT(university_name USING latin1) USING utf8mb4);

-- Check for orphaned records 
-- Check for universities in university_year that don't exist in the university table
Select distinct u1.university_id
FROM university_year u1
LEFT JOIN university u2 
on u1.university_id = u2.id
where u2.id is null ;

-- Check for ranking criteria in university_ranking_year that don't exist in ranking_criteria
select distinct u.ranking_criteria_id
from university_ranking_year u
left join ranking_criteria r
on u.ranking_criteria_id = r.id
where r.id is null ;

-- Check for countries in the university table that don't exist in the country table
select distinct u.country_id 
from university u 
left join country c
on u.country_id = c.id
where c.id is null;


-- EDA 

-- A. Descriptive Statistics and Distribution -- shape and spread of your core numerical data
-- Basic metric and Outliers

Select avg(num_students) as Avg_students , max(num_students) as max_students, stddev(num_students) as std_students,
avg(pct_international_students) as Avg_pct_international_students , avg(pct_female_students) as avg_pct_female_students, stddev(pct_female_students) as std_pct_female_students , stddev(pct_international_students) as _std_pct_international_students
from university_year; 

-- Score Districution of all univ acc different years keeping in mind only 'Total' score of the 3 criterias
Select Floor(score/10) * 10 as score_bucket, count(*)
from university_ranking_year ury
join ranking_criteria rc
on ury.ranking_criteria_id = rc.id 
where rc.criteria_name LIKE 'Total%'
group by 1
order by 1;

Select year, Floor(score/10) * 10 as score_bucket, count(*)
from university_ranking_year ury
join ranking_criteria rc
on ury.ranking_criteria_id = rc.id 
where rc.criteria_name LIKE 'Total%'
group by 1,2
order by 1,2;

-- Number of universities per country 
select c.country_name , count(distinct u.id) as no_of_countries  
from university u
join country c
on u.country_id = c.id
group by 1
order by 2 Desc; 

-- Number of uni per country for each ranking system
Select c.country_name , r.system_name , count(distinct ury.university_id) as no_of_univerisity
from university_ranking_year ury
join ranking_criteria rc on ury.ranking_criteria_id = rc.id
join ranking_system r on rc.ranking_system_id = r.id
join university u on u.id = ury.university_id
join country c on c.id = u.country_id
where  rc.criteria_name LIKE 'Total%'
group by 1,2
order by 3 Desc;

-- Total student year by year trend 
select year , sum(num_students) as total_students 
from university_year
group by year
order by 1;

-- Calculate the average overall ranking score globally per year
select ury.year , avg(ury.score) as average_score
from university_ranking_year ury
join ranking_criteria rc
on ury.ranking_criteria_id = rc.id
where rc.criteria_name LIKE 'Total%'
group by ury.year 
order by ury.year;

-- average student to staff ratio 
select year , avg(student_staff_ratio) as avg_ssr
from university_year
group by year
order by year;

-- Identify which university had the largest improvement in their average overall score from the first year to the last year available

With score_table as (select u.id as id , ury.year , ury.score , 
first_value(ury.score) over (partition by ury.university_id order by ury.year ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
) as first_score , 
last_value(ury.score) over (partition by ury.university_id order by ury.year ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
) as last_score
from university_ranking_year ury
join ranking_criteria rc
on ury.ranking_criteria_id = rc.id
join university u 
on u.id = ury.university_id
where rc.criteria_name LIKE 'Total%') 

select u.university_name, max(first_score) - max(last_score) as score_impv
from score_table rs
join university u on u.id = rs.id
group by u.university_name
order by score_impv desc
limit 10;

-- 6 7 
select c.country_name , avg(ury.score) , avg(uy.student_staff_ratio)
from university_ranking_year ury
join university u 
on u.id = ury.university_id
join ranking_criteria rc
on rc.id = ury.ranking_criteria_id
join country c 
on c.id = u.country_id 
join university_year uy 
on uy.university_id = ury.university_id
where rc.criteria_name LIKE 'Total%'
group by c.country_name
order by 2 DESC;

-- 6 7 
select c.country_name , count(distinct u.id), count(u.id)  ,  avg(ury.score) , avg(uy.student_staff_ratio)
,count(distinct rc.ranking_system_id) , group_concat(distinct rs.system_name order by rs.system_name SEPARATOR ', ')
from university_ranking_year ury
join university u 
on u.id = ury.university_id
join ranking_criteria rc
on rc.id = ury.ranking_criteria_id
join country c 
on c.id = u.country_id 
join university_year uy 
on uy.university_id = ury.university_id and uy.year = ury.year
LEFT JOIN ranking_system rs on rs.id = rc.ranking_system_id
where rc.criteria_name LIKE 'Total%'
group by c.country_name
order by 4 DESC;

-- avg score of univ in SSR Buckets and int student bucket
select 
    case
        when uy.student_staff_ratio < 10 then 'Low (<10: Best)'
        WHEN uy.student_staff_ratio between 10 and 15 then 'Medium (10–15)'
        else 'High (>15: Worst)'
    end as staff_ratio_group,
    case 
		when uy.pct_international_students > 30 then 'High intl %(>30)'
        when uy.pct_international_students between 15 and 30 then 'Moderate intl %(30-15)'
        when uy.pct_international_students < 15 then 'Low intl %(<15)'
	end as int_pct_grp,
    avg(ury.score) as avg_score
from university_year uy
join university_ranking_year ury 
    on uy.university_id = ury.university_id 
   and uy.year = ury.year
join ranking_criteria rc 
    on ury.ranking_criteria_id = rc.id
where rc.criteria_name like 'Total%'
group by 1,2
order by avg_score desc;

-- Calculate the average score for key individual criteria (e.g., Teaching, Research, Citations) for the top 25 performing universities
with ranked_univ as (
select ury.university_id as univ_id, avg(ury.score)
from university_ranking_year ury
join university u 
on u.id = ury.university_id
join ranking_criteria rc
on rc.id = ury.ranking_criteria_id
join university_year uy 
on uy.university_id = ury.university_id and uy.year = ury.year
LEFT JOIN ranking_system rs on rs.id = rc.ranking_system_id
where rc.criteria_name LIKE 'Total%'
group by ury.university_id
order by 2 desc
limit 25)

select rc.criteria_name, avg(ury.score)
from university_ranking_year ury
join ranking_criteria rc
on rc.id = ury.ranking_criteria_id
where ury.university_id in (select univ_id from ranked_univ )
	and rc.criteria_name in ('Teaching', 'Research', 'Citations', 'International')
group by rc.criteria_name
order by 1;

-- Calculates a relative rank (percentile) for both the overall score and the component score.

with ranked_score as (select ury.university_id , ury.year,
sum(case when rc.criteria_name like 'Total%' then ury.score else 0 end) as overall_score,
sum(case when rc.criteria_name like 'Citations%' then ury.score else 0 end) as citation_score,
sum(case when rc.criteria_name like 'Teaching%' then ury.score else 0 end) as teaching_score,
sum(case when rc.criteria_name like 'Research%' then ury.score else 0 end) as research_score,
sum(case when rc.criteria_name like 'International%' then ury.score else 0 end) as international_score
from university_ranking_year ury
join ranking_criteria rc
on rc.id = ury.ranking_criteria_id
where rc.ranking_system_id = 1
group by 1,2
order by 3 desc)

select u.university_name, rs.year ,
percent_rank() over (order by rs.overall_score) as overall_percentile,
percent_rank() over (order by rs.citation_score) as citation_percentile,
percent_rank() over (order by rs.teaching_score) as teaching_percentile,
percent_rank() over (order by rs.research_score) as research_percentile,
percent_rank() over (order by rs.international_score) as international_percentile
from ranked_score rs
join university u 
on rs.university_id = u.id
order by overall_percentile desc
limit 50; 


SELECT
    U.university_name,
    UY.year,
    UY.student_staff_ratio AS current_ssr,
    LAG(UY.student_staff_ratio, 1) OVER (
        PARTITION BY U.id 
        ORDER BY UY.year
    ) AS previous_ssr,
    UY.student_staff_ratio 
        - LAG(UY.student_staff_ratio, 1) OVER (
            PARTITION BY U.id 
            ORDER BY UY.year
        ) AS ssr_change
FROM university_year UY
JOIN university U 
    ON UY.university_id = U.id
WHERE UY.student_staff_ratio IS NOT NULL
ORDER BY ssr_change DESC
LIMIT 100;

