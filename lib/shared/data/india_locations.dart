/// Comprehensive and exhaustive database of ALL 28 Indian States, 8 Union Territories,
/// and their complete districts, cities, and major towns.
class IndiaLocations {
  static const Map<String, List<String>> stateDistricts = {
    'Andhra Pradesh': [
      'Visakhapatnam', 'Vijayawada (NTR)', 'Guntur', 'Nellore (SPSR Nellore)', 'Kurnool', 
      'Kakinada', 'Rajahmundry (East Godavari)', 'Tirupati', 'Kadapa (YSR)', 'Anantapur', 
      'Eluru', 'Vizianagaram', 'Srikakulam', 'Machilipatnam (Krishna)', 'Ongole (Prakasam)', 
      'Nandyal', 'Chittoor', 'Hindupur', 'Bhimavaram', 'Proddatur', 'Madanapalle', 
      'Narasaraopet', 'Tadepalligudem', 'Tenali', 'Anakapalli', 'Bapatla', 'Palnadu', 
      'Konaseema (Amalapuram)', 'Parvathipuram Manyam', 'Alluri Sitharama Raju (Paderu)', 
      'Annamayya (Rayachoti)', 'Sri Sathya Sai (Puttaparthi)'
    ],

    'Arunachal Pradesh': [
      'Itanagar', 'Naharlagun', 'Pasighat', 'Tawang', 'Ziro', 'Tezu', 'Roing', 
      'Bomdila', 'Aalo (Along)', 'Namsai', 'Changlang', 'Khonsa', 'Anini', 
      'Yingkiong', 'Daporijo', 'Seppa', 'Bhalukpong', 'Dirang', 'Basar', 
      'Longding', 'Jairampur', 'Raga', 'Hawai', 'Koloriang', 'Palin'
    ],

    'Assam': [
      'Guwahati (Kamrup Metropolitan)', 'Silchar (Cachar)', 'Dibrugarh', 'Jorhat', 
      'Nagaon', 'Tinsukia', 'Tezpur (Sonitpur)', 'Bongaigaon', 'Karimganj', 'Sivasagar', 
      'Dhubri', 'Goalpara', 'Barpeta', 'North Lakhimpur', 'Diphu (Karbi Anglong)', 
      'Golaghat', 'Hailakandi', 'Morigaon', 'Mangaldai (Darrang)', 'Kokrajhar', 
      'Nalbari', 'Hojai', 'Dhemaji', 'Chirang (Kajalgaon)', 'Baksa (Musalpur)', 
      'Udalguri', 'Biswanath Chariali', 'Charaideo (Sonari)', 'Dima Hasao (Haflong)', 
      'Majuli (Garamur)', 'South Salmara-Mankachar', 'West Karbi Anglong (Hamren)', 
      'Bajali (Pathsala)', 'Tamulpur'
    ],

    'Bihar': [
      'Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia', 'Darbhanga', 
      'Bihar Sharif (Nalanda)', 'Arrah (Bhojpur)', 'Begusarai', 'Katihar', 'Munger', 
      'Chhapra (Saran)', 'Sasaram (Rohtas)', 'Bettiah (West Champaran)', 'Dehri', 
      'Hajipur (Vaishali)', 'Motihari (East Champaran)', 'Siwan', 'Kishanganj', 'Buxar', 
      'Sitamarhi', 'Jamalpur', 'Jehanabad', 'Aurangabad', 'Nawada', 'Madhubani', 
      'Samastipur', 'Saharsa', 'Supaul', 'Gopalganj', 'Khagaria', 'Araria', 
      'Jamui', 'Madhepura', 'Banka', 'Lakhisarai', 'Sheikhpura', 'Sheohar', 
      'Kaimur (Bhabua)', 'Arwal'
    ],

    'Chhattisgarh': [
      'Raipur', 'Bhilai (Durg)', 'Bilaspur', 'Korba', 'Rajnandgaon', 'Jagdalpur (Bastar)', 
      'Raigarh', 'Ambikapur (Surguja)', 'Dhamtari', 'Mahasamund', 'Kanker (Uttar Bastar)', 
      'Kawardha (Kabirdham)', 'Janjgir-Champa', 'Balod', 'Bemetara', 'Mungeli', 
      'Kondagaon', 'Sukma', 'Dantewada (Dakshin Bastar)', 'Bijapur', 'Narayanpur', 
      'Gariaband', 'Baloda Bazar', 'Korea (Baikunthpur)', 'Surajpur', 'Balrampur', 
      'Jashpur', 'Sakti', 'Sarangarh-Bilaigarh', 'Manendragarh-Chirmiri-Bharatpur', 
      'Mohla-Manpur-Ambagarh Chowki', 'Khairagarh-Chhuikhadan-Gandai', 'Gaurela-Pendra-Marwahi'
    ],

    'Goa': [
      'North Goa (Panaji)', 'South Goa (Margao)', 'Vasco da Gama', 'Mapusa', 'Ponda', 
      'Calangute', 'Candolim', 'Bicholim', 'Curchorem', 'Canacona', 'Pernem', 
      'Valpoi', 'Quepem', 'Sanguem', 'Porvorim', 'Cuncolim', 'Anjuna', 'Baga'
    ],

    'Gujarat': [
      'Ahmedabad', 'Surat', 'Vadodara (Baroda)', 'Rajkot', 'Bhavnagar', 'Jamnagar', 
      'Gandhinagar', 'Junagadh', 'Anand', 'Navsari', 'Bharuch', 'Morbi', 'Vapi', 
      'Valsad', 'Porbandar', 'Godhra (Panchmahal)', 'Bhuj (Kutch)', 'Gandhidham', 
      'Mehsana', 'Palanpur (Banaskantha)', 'Patan', 'Himatnagar (Sabar Kantha)', 
      'Amreli', 'Surendranagar', 'Nadiad (Kheda)', 'Botad', 'Dahod', 'Veraval (Gir Somnath)', 
      'Vyara (Tapi)', 'Modasa (Aravalli)', 'Chhota Udaipur', 'Mahisagar (Lunawada)', 
      'Ahwa (Dang)', 'Anjar', 'Mundra', 'Keshod', 'Jetpur', 'Dhoraji', 'Gondal'
    ],

    'Haryana': [
      'Gurugram (Gurgaon)', 'Faridabad', 'Panipat', 'Ambala', 'Yamunanagar', 'Rohtak', 
      'Hisar', 'Karnal', 'Sonipat', 'Panchkula', 'Sirsa', 'Bhiwani', 'Bahadurgarh', 
      'Jind', 'Thanesar (Kurukshetra)', 'Kaithal', 'Rewari', 'Palwal', 'Jagadhri', 
      'Fatehabad', 'Narnaul (Mahendragarh)', 'Jhajjar', 'Charkhi Dadri', 'Nuh (Mewat)', 
      'Tohana', 'Hansi', 'Narwana', 'Sohna', 'Manesar', 'Pehowa', 'Kalka'
    ],

    'Himachal Pradesh': [
      'Shimla', 'Dharamshala (Kangra)', 'Mandi', 'Solan', 'Kullu', 'Manali', 'Baddi', 
      'Bilaspur', 'Hamirpur', 'Una', 'Chamba', 'Nahan (Sirmaur)', 'Paonta Sahib', 
      'Palampur', 'Kalka-Shimla region', 'Keylong (Lahaul and Spiti)', 'Reckong Peo (Kinnaur)', 
      'Dalhousie', 'Sundernagar', 'Nalagarh', 'Parwanoo', 'Kasauli', 'Jogindernagar', 'Nurpur'
    ],

    'Jharkhand': [
      'Ranchi', 'Jamshedpur (East Singhbhum)', 'Dhanbad', 'Bokaro Steel City', 'Deoghar', 
      'Hazaribagh', 'Giridih', 'Ramgarh', 'Medininagar (Daltonganj - Palamu)', 
      'Chaibasa (West Singhbhum)', 'Dumka', 'Sahibganj', 'Pakur', 'Godda', 'Jamtara', 
      'Koderma (Jhumri Telaiya)', 'Chatra', 'Latehar', 'Lohardaga', 'Gumla', 'Simdega', 
      'Khunti', 'Saraikela Kharsawan', 'Garhwa', 'Chas', 'Ghatshila', 'Bhurkunda'
    ],

    'Karnataka': [
      'Bangalore Urban (Bengaluru)', 'Bangalore Rural', 'Mysore (Mysuru)', 'Hubli-Dharwad', 
      'Mangalore (Dakshina Kannada)', 'Belgaum (Belagavi)', 'Gulbarga (Kalaburagi)', 
      'Davanagere', 'Bellary (Ballari)', 'Shimoga (Shivamogga)', 'Tumkur (Tumakuru)', 
      'Udupi', 'Bidar', 'Hassan', 'Raichur', 'Bijapur (Vijayapura)', 'Mandya', 
      'Chikmagalur (Chikkamagaluru)', 'Kolar', 'Chitradurga', 'Gadag', 'Bagalkot', 
      'Karwar (Uttara Kannada)', 'Haveri', 'Yadgir', 'Ramanagara', 'Chamarajanagar', 
      'Koppal', 'Madikeri (Kodagu)', 'Vijayanagara (Hospet)', 'Chikkaballapur', 
      'Bhadravati', 'Gokak', 'Sirsi', 'Kundapura', 'Puttur', 'Robertsonpet (KGF)'
    ],

    'Kerala': [
      'Thiruvananthapuram (Trivandrum)', 'Kochi (Ernakulam)', 'Kozhikode (Calicut)', 
      'Thrissur', 'Kollam (Quilon)', 'Kannur', 'Alappuzha (Alleppey)', 'Kottayam', 
      'Palakkad', 'Malappuram', 'Kasaragod', 'Pathanamthitta', 'Idukki (Munnar/Painavu)', 
      'Wayanad (Kalpetta)', 'Thalassery', 'Ponnani', 'Vatakara', 'Kanhangad', 
      'Payyanur', 'Koyilandy', 'Neyyattinkara', 'Kayamkulam', 'Nedumangad', 'Manjeri', 
      'Perinthalmanna', 'Aluva', 'Tirur', 'Changanassery', 'Muvattupuzha'
    ],

    'Madhya Pradesh': [
      'Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain', 'Sagar', 'Dewas', 'Satna', 
      'Ratlam', 'Rewa', 'Singrauli', 'Burhanpur', 'Khandwa', 'Morena', 'Bhind', 
      'Shivpuri', 'Chhindwara', 'Damoh', 'Mandsaur', 'Neemuch', 'Hoshangabad (Narmadapuram)', 
      'Itarsi', 'Sehore', 'Vidisha', 'Betul', 'Seoni', 'Datia', 'Dhar', 'Khargone (West Nimar)', 
      'Barwani', 'Balaghat', 'Katni', 'Panna', 'Chhatarpur', 'Tikamgarh', 'Shahdol', 
      'Umaria', 'Anuppur', 'Mandla', 'Dindori', 'Harda', 'Raisen', 'Rajgarh', 'Shajapur', 
      'Agar Malwa', 'Guna', 'Ashoknagar', 'Sheopur', 'Sidhi', 'Maihar', 'Pandhurna', 
      'Mauganj', 'Nagda', 'Sendhwa', 'Sanawad', 'Ganjbasoda', 'Pipariya', 'Pithampur'
    ],

    'Maharashtra': [
      'Pune', 'Mumbai City', 'Mumbai Suburban', 'Thane', 'Navi Mumbai', 'Nagpur', 'Nashik', 
      'Kalyan-Dombivli', 'Vasai-Virar', 'Aurangabad (Chhatrapati Sambhajinagar)', 'Solapur', 
      'Kolhapur', 'Amravati', 'Nanded', 'Jalgaon', 'Akola', 'Latur', 'Dhule', 
      'Ahmednagar (Ahilyanagar)', 'Chandrapur', 'Parbhani', 'Ichalkaranji', 'Jalna', 
      'Ambarnath', 'Bhusawal', 'Panvel', 'Badlapur', 'Beed', 'Gondia', 'Satara', 
      'Barshi', 'Yavatmal', 'Achalpur', 'Osmanabad (Dharashiv)', 'Nandurbar', 'Wardha', 
      'Bhandara', 'Ratnagiri', 'Sindhudurg (Oros)', 'Gadchiroli', 'Hingoli', 'Washim', 
      'Palghar', 'Baramati', 'Khamgaon', 'Pandharpur', 'Uran Islampur', 'Malegaon', 
      'Karad', 'Sangamner', 'Chalisgaon', 'Pimpri-Chinchwad', 'Mira-Bhayandar'
    ],

    'Manipur': [
      'Imphal East', 'Imphal West', 'Thoubal', 'Bishnupur', 'Churachandpur', 'Kakching', 
      'Ukhrul', 'Senapati', 'Tamenglong', 'Chandel', 'Kangpokpi', 'Jiribam', 
      'Tengnoupal', 'Kamjong', 'Noney', 'Pherzawl', 'Moirang', 'Lilong', 'Mayang Imphal'
    ],

    'Meghalaya': [
      'Shillong (East Khasi Hills)', 'Tura (West Garo Hills)', 'Jowai (West Jaintia Hills)', 
      'Nongpoh (Ri-Bhoi)', 'Williamnagar (East Garo Hills)', 'Baghmara (South Garo Hills)', 
      'Resubelpara (North Garo Hills)', 'Nongstoin (West Khasi Hills)', 
      'Mairang (Eastern West Khasi Hills)', 'Khliehriat (East Jaintia Hills)', 
      'Mawkyrwat (South West Khasi Hills)', 'Ampati (South West Garo Hills)', 'Cherrapunji (Sohra)'
    ],

    'Mizoram': [
      'Aizawl', 'Lunglei', 'Champhai', 'Serchhip', 'Kolasib', 'Lawngtlai', 'Saiha (Siaha)', 
      'Mamit', 'Hnahthial', 'Khawzawl', 'Saitual', 'Bairabi', 'Vairengte', 'Zawlnuam'
    ],

    'Nagaland': [
      'Kohima', 'Dimapur', 'Mokokchung', 'Tuensang', 'Wokha', 'Zunheboto', 'Mon', 
      'Phek', 'Kiphire', 'Longleng', 'Peren', 'Chumoukedima', 'Niuland', 'Tseminyu', 
      'Shamator', 'Noklak', 'Medziphema'
    ],

    'Odisha': [
      'Angul', 'Talcher', 'Banarpal', 'Nalco Nagar', 'Kaniha', 'Chendipada', 'Athamallik', 'Boinda', 'Pallahara', 'Kishore Nagar', 'Jarapada', 'Turanga', 'Hakimpara', 'Amalapada', 'Similipada', 'Mishrapada',
      'Bhubaneswar (Khurda)', 'Khordha', 'Jatni', 'Balugaon', 'Banapur', 'Saheed Nagar', 'Patia', 'Nayapalli', 'Chandrasekharpur', 'Khandagiri', 'Old Town',
      'Cuttack', 'Choudwar', 'Athagarh', 'Banki', 'Salipur', 'Badambadi', 'CDA', 'Link Road', 'College Square',
      'Rourkela (Sundargarh)', 'Sundargarh', 'Rajgangpur', 'Biramitrapur', 'Panposh', 'Uditnagar',
      'Berhampur (Ganjam)', 'Ganjam', 'Chhatrapur', 'Hinjilicut', 'Bhanjanagar', 'Aska', 'Polasara', 'Bellaguntha',
      'Sambalpur', 'Burla', 'Hirakud', 'Kuchinda', 'Rairakhol', 'Ainthapali',
      'Puri', 'Konark', 'Nimapada', 'Pipili', 'Brahmagiri', 'Satyabadi', 'Kakatpur',
      'Balasore (Baleswar)', 'Soro', 'Jaleswar', 'Nilagiri', 'Basta', 'Bhograi',
      'Bhadrak', 'Chandbali', 'Dhamnagar', 'Basudevpur', 'Bonth', 'Dhamra',
      'Baripada (Mayurbhanj)', 'Rairangpur', 'Karanjia', 'Udala', 'Betnoti', 'Jashipur',
      'Jharsuguda', 'Brajarajnagar', 'Belpahar', 'Kolabira', 'Laikera',
      'Jeypore (Koraput)', 'Koraput', 'Sunabeda', 'Damanjodi', 'Semiliguda', 'Kotpad',
      'Bargarh', 'Padampur', 'Attabira', 'Barpali', 'Sohela', 'Bhatli',
      'Balangir', 'Titilagarh', 'Patnagarh', 'Kantabanji', 'Tusura', 'Loisingha',
      'Rayagada', 'Gunupur', 'Bissam Cuttack', 'Muniguda', 'Chandrapur',
      'Dhenkanal', 'Kamakhyanagar', 'Bhuban', 'Hindol', 'Gondia', 'Parjang',
      'Kendrapara', 'Pattamundai', 'Aul', 'Rajkanika', 'Marsaghai', 'Derabish',
      'Jagatsinghpur', 'Paradeep', 'Tirtol', 'Kujang', 'Balikuda', 'Raghunathpur',
      'Jajpur', 'Jajpur Road (Vyasanagar)', 'Chandikhole', 'Sukinda', 'Dharmasala', 'Kuakhia',
      'Keonjhar (Kendujhar)', 'Barbil', 'Joda', 'Anandapur', 'Champua', 'Ghatagaon', 'Telkoi',
      'Nabarangpur', 'Umerkote', 'Chandahandi', 'Raighar', 'Dabugaon',
      'Nuapada', 'Khariar', 'Khariar Road', 'Sinapali', 'Komna',
      'Kandhamal (Phulbani)', 'Baliguda', 'G.Udayagiri', 'Daringbadi', 'Tikabali',
      'Malkangiri', 'Balimela', 'Kalimela', 'Mathili', 'Chitrakonda',
      'Nayagarh', 'Khandapada', 'Odagaon', 'Ranpur', 'Dasapalla', 'Fategarh',
      'Subarnapur (Sonepur)', 'Tarbha', 'Birmaharajpur', 'Ullunda', 'Dunguripali',
      'Boudh', 'Kantamal', 'Harbhanga',
      'Deogarh', 'Barkote', 'Reamal',
      'Gajapati (Paralakhemundi)', 'Kashinagar', 'Mohana', 'R.Udayagiri',
      'Kalahandi (Bhawanipatna)', 'Kesinga', 'Dharmagarh', 'Junagarh', 'Jaipatna', 'Lanjigarh'
    ],

    'Punjab': [
      'Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Mohali (SAS Nagar)', 
      'Hoshiarpur', 'Batala', 'Pathankot', 'Moga', 'Abohar', 'Malerkotla', 'Khanna', 
      'Phagwara', 'Muktsar (Sri Muktsar Sahib)', 'Barnala', 'Firozpur', 'Kapurthala', 
      'Rajpura', 'Sangrur', 'Fazilka', 'Mansa', 'Gurdaspur', 'Faridkot', 
      'Nawanshahr (Shaheed Bhagat Singh Nagar)', 'Tarn Taran', 'Ropar (Rupnagar)', 
      'Fatehgarh Sahib (Sirhind)', 'Zirakpur', 'Kharar', 'Dera Bassi', 'Sunam', 'Samana'
    ],

    'Rajasthan': [
      'Jaipur', 'Jodhpur', 'Kota', 'Bikaner', 'Ajmer', 'Udaipur', 'Bhilwara', 'Alwar', 
      'Bharatpur', 'Sikar', 'Pali', 'Sri Ganganagar', 'Hanumangarh', 'Beawar', 'Kishangarh', 
      'Jhunjhunu', 'Churu', 'Tonk', 'Sawai Madhopur', 'Chittorgarh', 'Barmer', 'Jalore', 
      'Sirohi (Mount Abu)', 'Nagaur', 'Banswara', 'Dungarpur', 'Pratapgarh', 'Rajsamand', 
      'Jhalawar', 'Baran', 'Bundi', 'Dausa', 'Dholpur', 'Karauli', 'Jaisalmer', 'Balotra', 
      'Anupgarh', 'Didwana-Kuchaman', 'Kotputli-Behror', 'Khairthal-Tijara', 'Neem Ka Thana', 
      'Phalodi', 'Salumbar', 'Sanchore', 'Shahpura', 'Deeg', 'Gangapur City', 'Dudu', 
      'Hindaun', 'Sujangarh', 'Fatehpur Shekhawati', 'Makrana', 'Nimbahera'
    ],

    'Sikkim': [
      'Gangtok', 'Namchi', 'Geyzing (Gyalshing)', 'Mangan', 'Soreng', 'Pakyong', 
      'Ravangla', 'Singtam', 'Rangpo', 'Jorethang', 'Pelling', 'Lachung', 'Lachen', 'Rhenock'
    ],

    'Tamil Nadu': [
      'Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli (Trichy)', 'Salem', 'Tirunelveli', 
      'Tiruppur', 'Erode', 'Vellore', 'Thoothukudi (Tuticorin)', 'Dindigul', 'Thanjavur', 
      'Ranipet', 'Sivakasi (Virudhunagar)', 'Karur', 'Udhagamandalam (Ooty - Nilgiris)', 
      'Hosur (Krishnagiri)', 'Nagercoil (Kanyakumari)', 'Kanchipuram', 'Kumbakonam', 
      'Cuddalore', 'Tiruvannamalai', 'Nagapattinam', 'Pudukkottai', 'Ariyalur', 'Chengalpattu', 
      'Kallakurichi', 'Mayiladuthurai', 'Namakkal', 'Perambalur', 'Ramanathapuram', 
      'Tenkasi', 'Theni', 'Thiruvallur', 'Thiruvarur', 'Tirupathur', 'Viluppuram', 
      'Pollachi', 'Rajapalayam', 'Gudiyatham', 'Ambur', 'Vaniyambadi', 'Neyveli', 'Karaikudi'
    ],

    'Telangana': [
      'Hyderabad', 'Secunderabad', 'Warangal (Hanamkonda)', 'Nizamabad', 'Karimnagar', 
      'Khammam', 'Ramagundam (Peddapalli)', 'Mahabubnagar', 'Nalgonda', 'Adilabad', 
      'Suryapet', 'Siddipet', 'Miryalaguda', 'Jagtial', 'Nirmal', 'Kamareddy', 
      'Kothagudem (Bhadradri)', 'Mancherial', 'Sangareddy', 'Medak', 'Vikarabad', 
      'Jangaon', 'Wanaparthy', 'Gadwal (Jogulamba)', 'Nagarkurnool', 'Bhuvanagiri (Yadadri)', 
      'Asifabad (Komaram Bheem)', 'Bhupalpally (Jayashankar)', 'Mulugu', 'Narayanpet', 
      'Medchal-Malkajgiri', 'Ranga Reddy (Shamshabad)', 'Sircilla (Rajanna)', 'Bellampalli', 
      'Bodhan', 'Mandamarri', 'Palwancha', 'Tandur', 'Koratla'
    ],

    'Tripura': [
      'Agartala (West Tripura)', 'Dharmanagar (North Tripura)', 'Udaipur (Gomati)', 
      'Kailashahar (Unakoti)', 'Belonia (South Tripura)', 'Khowai', 'Ambassa (Dhalai)', 
      'Teliamura', 'Bishalgarh (Sepahijala)', 'Melaghar', 'Sabroom', 'Sonamura', 
      'Santirbazar', 'Amarpur', 'Kumarghat'
    ],

    'Uttar Pradesh': [
      'Lucknow', 'Kanpur', 'Varanasi (Kashi)', 'Agra', 'Noida (Gautam Buddha Nagar)', 
      'Greater Noida', 'Ghaziabad', 'Prayagraj (Allahabad)', 'Meerut', 'Bareilly', 
      'Aligarh', 'Moradabad', 'Gorakhpur', 'Saharanpur', 'Jhansi', 'Mathura (Vrindavan)', 
      'Ayodhya (Faizabad)', 'Muzaffarnagar', 'Firozabad', 'Budaun', 'Rampur', 
      'Shahjahanpur', 'Farrukhabad', 'Etawah', 'Sambhal', 'Amroha', 'Hardoi', 
      'Fatehpur', 'Raebareli', 'Orai (Jalaun)', 'Sitapur', 'Bahraich', 'Unnao', 
      'Jaunpur', 'Lakhimpur Kheri', 'Hathras', 'Banda', 'Pilibhit', 'Barabanki', 
      'Gonda', 'Basti', 'Mirzapur', 'Deoria', 'Azamgarh', 'Mau', 'Ballia', 
      'Ghazipur', 'Sultanpur', 'Amethi', 'Bhadohi', 'Bijnor', 'Bulandshahr', 
      'Chandauli', 'Chitrakoot', 'Etah', 'Hapur', 'Hamirpur', 'Jalaun', 'Kannauj', 
      'Kasganj', 'Kaushambi', 'Lalitpur', 'Mahoba', 'Mainpuri', 'Maharajganj', 
      'Sant Kabir Nagar (Khalilabad)', 'Shamli', 'Shravasti', 'Siddharthnagar', 
      'Sonbhadra (Robertsganj)', 'Modinagar', 'Khurja', 'Shikohabad', 'Chandausi'
    ],

    'Uttarakhand': [
      'Dehradun', 'Haridwar', 'Roorkee', 'Haldwani (Nainital)', 'Rishikesh', 
      'Rudrapur (Udham Singh Nagar)', 'Kashipur', 'Kotdwar (Pauri Garhwal)', 'Almora', 
      'Pithoragarh', 'Mussoorie', 'Chamoli (Gopeshwar)', 'Tehri Garhwal (New Tehri)', 
      'Uttarkashi', 'Champawat', 'Bageshwar', 'Rudraprayag', 'Ramnagar', 'Kichha', 
      'Manglaur', 'Jaspur', 'Vikasnagar', 'Joshimath', 'Ranikhet'
    ],

    'West Bengal': [
      'Kolkata', 'Howrah', 'North 24 Parganas (Barasat/Bidhannagar/Salt Lake)', 
      'South 24 Parganas (Alipore/Baruipur)', 'Hooghly (Chinsurah/Serampore/Chandannagar)', 
      'Paschim Bardhaman (Asansol/Durgapur)', 'Purba Bardhaman (Bardhaman)', 
      'Darjeeling (Siliguri)', 'Nadia (Kalyani/Krishnanagar)', 'Murshidabad (Berhampore)', 
      'Malda (English Bazar)', 'Jalpaiguri', 'Alipurduar', 'Cooch Behar', 
      'Uttar Dinajpur (Raiganj)', 'Dakshin Dinajpur (Balurghat)', 'Purba Medinipur (Tamluk/Haldia)', 
      'Paschim Medinipur (Midnapore/Kharagpur)', 'Jhargram', 'Bankura', 'Purulia', 
      'Birbhum (Suri/Bolpur/Santiniketan)', 'Kalimpong', 'Kanchrapara', 'Habra', 
      'Bhatpara', 'Panihati', 'Kamarhati', 'Barrackpore', 'Bally', 'Rishra', 'Ranaghat'
    ],

    'Delhi (UT)': [
      'Central Delhi', 'New Delhi', 'South Delhi', 'North Delhi', 'East Delhi', 
      'West Delhi', 'North East Delhi', 'South West Delhi', 'North West Delhi', 
      'Shahdara', 'South East Delhi', 'Connaught Place', 'Dwarka', 'Rohini', 
      'Saket', 'Karol Bagh', 'Lajpat Nagar', 'Vasant Kunj', 'Janakpuri', 'Pitampura'
    ],

    'Jammu and Kashmir (UT)': [
      'Srinagar', 'Jammu', 'Anantnag', 'Baramulla', 'Udhampur', 'Sopore', 'Kathua', 
      'Poonch', 'Rajouri', 'Pulwama', 'Kupwara', 'Budgam', 'Ganderbal', 'Kulgam', 
      'Bandipora', 'Samba', 'Reasi (Katra)', 'Doda', 'Ramban', 'Kishtwar', 'Akhnoor'
    ],

    'Ladakh (UT)': [
      'Leh', 'Kargil', 'Nubra Valley', 'Dras', 'Zanskar', 'Changthang', 'Khaltsi'
    ],

    'Chandigarh (UT)': [
      'Chandigarh City', 'Sector 17', 'Sector 35', 'Sector 22', 'Manimajra', 'Sector 43'
    ],

    'Puducherry (UT)': [
      'Puducherry (Pondicherry)', 'Karaikal', 'Mahe', 'Yanam', 'Oulgaret', 'Villianur'
    ],

    'Andaman and Nicobar Islands (UT)': [
      'Port Blair (South Andaman)', 'Diglipur (North and Middle Andaman)', 
      'Car Nicobar (Nicobar)', 'Havelock Island (Swaraj Dweep)', 'Neil Island (Shaheed Dweep)', 
      'Mayabunder', 'Rangat', 'Campbell Bay'
    ],

    'Dadra and Nagar Haveli and Daman and Diu (UT)': [
      'Daman', 'Diu', 'Silvassa', 'Dadra', 'Naroli', 'Bhimpore'
    ],

    'Lakshadweep (UT)': [
      'Kavaratti', 'Agatti', 'Andrott', 'Minicoy', 'Amini', 'Kadmat', 'Kalpeni'
    ],
  };

  /// Returns all state and union territory names sorted alphabetically
  static List<String> getAllStates() {
    return stateDistricts.keys.toList()..sort();
  }

  /// Returns all districts / cities for a state or UT
  static List<String> getDistrictsForState(String state) {
    return stateDistricts[state] ?? [];
  }

  /// Searches states, districts, and cities matching a search query
  static List<Map<String, String>> searchLocations(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    final List<Map<String, String>> results = [];

    stateDistricts.forEach((state, districts) {
      if (state.toLowerCase().contains(q)) {
        results.add({'type': 'State/UT', 'name': state, 'state': state});
      }
      for (final district in districts) {
        if (district.toLowerCase().contains(q)) {
          results.add({'type': 'City/District', 'name': district, 'state': state});
        }
      }
    });

    return results;
  }

  /// Resolves the parent district for a city, village, or town within a state
  static String? resolveDistrictForCity(String cityOrLocality, String state) {
    final cleanCity = cityOrLocality.trim().toLowerCase();
    final cleanState = state.trim().toLowerCase();

    // Map known towns/villages to their canonical district
    const Map<String, Map<String, String>> townToDistrict = {
      'odisha': {
        'pallahara': 'Angul',
        'palalahara': 'Angul',
        'talcher': 'Angul',
        'banarpal': 'Angul',
        'kaniha': 'Angul',
        'chendipada': 'Angul',
        'athamallik': 'Angul',
        'boinda': 'Angul',
        'kishore nagar': 'Angul',
        'jarapada': 'Angul',
        'turanga': 'Angul',
        'hakimpara': 'Angul',
        'amalapada': 'Angul',
        'similipada': 'Angul',
        'mishrapada': 'Angul',
        'khamar': 'Angul',
        'bhubaneswar': 'Khurda',
        'jatni': 'Khurda',
        'patia': 'Khurda',
        'saheed nagar': 'Khurda',
        'nayapalli': 'Khurda',
        'chandrasekharpur': 'Khurda',
        'khandagiri': 'Khurda',
        'choudwar': 'Cuttack',
        'athagarh': 'Cuttack',
        'banki': 'Cuttack',
        'salipur': 'Cuttack',
        'badambadi': 'Cuttack',
        'rourkela': 'Sundargarh',
        'rajgangpur': 'Sundargarh',
        'berhampur': 'Ganjam',
        'chhatrapur': 'Ganjam',
        'hinjilicut': 'Ganjam',
        'bhanjanagar': 'Ganjam',
        'aska': 'Ganjam',
        'burla': 'Sambalpur',
        'hirakud': 'Sambalpur',
        'konark': 'Puri',
        'pipili': 'Puri',
        'nimapada': 'Puri',
        'soro': 'Balasore',
        'jaleswar': 'Balasore',
      },
    };

    if (townToDistrict.containsKey(cleanState)) {
      final district = townToDistrict[cleanState]![cleanCity];
      if (district != null) return district;
    }

    final stateList = stateDistricts.entries.firstWhere(
      (e) => e.key.toLowerCase() == cleanState,
      orElse: () => const MapEntry('', []),
    ).value;

    for (final item in stateList) {
      if (item.toLowerCase() == cleanCity || item.toLowerCase().startsWith('$cleanCity ')) {
        return item.contains('(') ? item.split('(').first.trim() : item;
      }
    }

    return null;
  }
}
