<?php

/**

 * KoyoUMKM API - Model A (single API file)

 * Requires: php/config.php, php/db.php, php/validator.php

 * Existing legacy submissions are kept untouched. New submissions require evaluation periods.

 */

declare(strict_types=1);

require_once __DIR__ . '/php/security.php';

require_once __DIR__ . '/php/config.php';

require_once __DIR__ . '/php/db.php';

require_once __DIR__ . '/php/validator.php';



header('Content-Type: application/json; charset=utf-8');

vistraApplyCors();



function apiOut(bool $ok, $data = null, string $message = '', int $status = 200): never {

    http_response_code($status);

    echo json_encode(['success'=>$ok, 'data'=>$data, 'message'=>$message], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);

    exit;

}

function apiInput(): array {

    $raw = file_get_contents('php://input');

    $data = json_decode($raw ?: '', true);

    return is_array($data) ? $data : $_POST;

}

function b64url(string $v): string { return rtrim(strtr(base64_encode($v), '+/', '-_'), '='); }

function makeToken(int $uid): string {

    $h = b64url(json_encode(['alg'=>'HS256','typ'=>'JWT']));

    $p = b64url(json_encode(['user_id'=>$uid,'iat'=>time(),'exp'=>time()+(int)JWT_EXPIRE]));

    $s = b64url(hash_hmac('sha256', "$h.$p", JWT_SECRET, true));

    return "$h.$p.$s";

}

function readToken(string $token): ?array {

    $parts = explode('.', $token);

    if (count($parts)!==3) return null;

    [$h,$p,$s] = $parts;

    $expected = b64url(hash_hmac('sha256', "$h.$p", JWT_SECRET, true));

    if (!hash_equals($expected, $s)) return null;

    $payload = json_decode(base64_decode(strtr($p, '-_', '+/')), true);

    return is_array($payload) && (int)($payload['exp']??0) >= time() ? $payload : null;

}

function currentUser(): array {

    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';

    if (!$header && function_exists('apache_request_headers')) {

        $headers = apache_request_headers(); $header = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    }

    $token = preg_replace('/^Bearer\\s+/i', '', trim((string)$header));

    $payload = readToken($token);

    if (!$payload) apiOut(false, null, 'Sesi login berakhir. Silakan login kembali.', 401);

    $user = DB::fetchOne('SELECT id,umkm_id,umkm_name,email,role,lokasi,sektor,omzet,is_active,created_at FROM users WHERE id=?', [(int)$payload['user_id']]);

    if (!$user || (int)$user['is_active'] !== 1) apiOut(false, null, 'Akun tidak aktif atau tidak ditemukan.', 403);

    if ($user['role'] !== 'platform_admin' && empty($user['umkm_id'])) apiOut(false, null, 'Akun belum terhubung ke UMKM. Hubungi administrator.', 403);

    return $user;

}

function needOwner(array $u): void { if (!in_array($u['role'], ['owner','platform_admin'], true)) apiOut(false,null,'Akses hanya untuk Owner.',403); }

// Read-only: a closed/latest period is never reopened by status or submit.
function currentEvaluationPeriod(int $umkmId): ?array {
    return DB::fetchOne('SELECT * FROM evaluation_periods WHERE umkm_id=? ORDER BY id DESC LIMIT 1', [$umkmId]);
}


function callN8nPredict(array $payload): array {

    // n8n bersifat opsional. Jika tunnel mati, backend tetap menghitung dengan PHP.

    $url = defined('N8N_WEBHOOK_URL') ? (string)N8N_WEBHOOK_URL : '';

    if ($url === '') return ['ok'=>false,'error'=>'n8n tidak tersedia'];

    if (!function_exists('curl_init')) return ['ok'=>false,'error'=>'cURL tidak tersedia'];

    $ch = curl_init($url);

    curl_setopt_array($ch,[CURLOPT_POST=>true,CURLOPT_RETURNTRANSFER=>true,

        CURLOPT_HTTPHEADER=>['Content-Type: application/json','Accept: application/json'],

        CURLOPT_POSTFIELDS=>json_encode($payload,JSON_UNESCAPED_UNICODE),

        CURLOPT_CONNECTTIMEOUT=>3,CURLOPT_TIMEOUT=>8,CURLOPT_SSL_VERIFYPEER=>true,CURLOPT_SSL_VERIFYHOST=>2]);

    $response=curl_exec($ch); $code=(int)curl_getinfo($ch,CURLINFO_HTTP_CODE); curl_close($ch);

    if ($response===false || $code<200 || $code>=300) return ['ok'=>false,'error'=>'n8n tidak tersedia'];

    $json=json_decode($response,true);

    return is_array($json) && ($json['success']??false)===true ? ['ok'=>true,'data'=>$json['data']??null] : ['ok'=>false,'error'=>'Respons n8n tidak valid'];

}

function logWarnings(int $sid, array $warnings): void {

    foreach ($warnings as $w) {

        DB::execute('INSERT INTO validation_log(submission_id,level,factor_key,field_name,error_code,message) VALUES(?,?,?,?,?,?)',

            [$sid,'warning',$w['factor']??null,$w['field']??null,$w['code']??'WARNING',$w['message']??'']);

    }

}

function calculatePeriodResult(int $periodId, int $umkmId): ?array {

    $period = DB::fetchOne('SELECT * FROM evaluation_periods WHERE id=? AND umkm_id=?', [$periodId,$umkmId]);

    if (!$period) return null;

    $owner = DB::fetchOne("SELECT s.* FROM submissions s JOIN users u ON u.id=s.user_id WHERE s.period_id=? AND s.role='owner' AND s.status='validated' AND s.validation_pass=1 AND u.umkm_id=? AND u.is_active=1 AND s.score_ins IS NOT NULL AND s.score_ops IS NOT NULL AND s.score_ect IS NOT NULL LIMIT 1", [$periodId,$umkmId]);

    $employees = DB::fetchAll("SELECT s.* FROM submissions s JOIN users u ON u.id=s.user_id WHERE s.period_id=? AND s.role='employee' AND s.status='validated' AND s.validation_pass=1 AND u.umkm_id=? AND u.is_active=1 AND s.score_ov IS NOT NULL AND s.score_ldi IS NOT NULL AND s.score_weq IS NOT NULL ORDER BY s.id", [$periodId,$umkmId]);

    if (!$owner || count($employees) < max(1,(int)$period['min_employee_responses'])) return null;



    $scores = [

        'INS' => (float)$owner['score_ins'],

        'OPS' => (float)$owner['score_ops'],

        'ECT' => (float)$owner['score_ect'],

        'OV'  => array_sum(array_map(fn($r)=>(float)$r['score_ov'],$employees))/count($employees),

        'LDI' => array_sum(array_map(fn($r)=>(float)$r['score_ldi'],$employees))/count($employees),

        'WEQ' => array_sum(array_map(fn($r)=>(float)$r['score_weq'],$employees))/count($employees),

    ];

    $weights = ['INS'=>.20,'OV'=>.18,'LDI'=>.17,'WEQ'=>.15,'OPS'=>.15,'ECT'=>.15];

    $composite = 0.0;

    foreach ($weights as $key=>$weight) $composite += $scores[$key]*$weight;

    $composite = round($composite,4);

    $score5 = round($composite*5,2);

    $category = $composite>=.80?'SANGAT BAIK':($composite>=.60?'BAIK':($composite>=.40?'CUKUP':'PERLU PERHATIAN'));



    $pdo = DB::pdo();

    $pdo->beginTransaction();

    try {

        $old = DB::fetchOne('SELECT id FROM evaluation_results WHERE umkm_id=? AND period_id=? FOR UPDATE', [$umkmId,$periodId]);

        if ($old) {

            $rid = (int)$old['id'];

            DB::execute('UPDATE evaluation_results SET score_composite=?,score_on_5=?,health_category=?,respondent_count=?,status="published",calculated_at=NOW(),published_at=NOW() WHERE id=?', [$composite,$score5,$category,count($employees)+1,$rid]);

            DB::execute('DELETE FROM result_factor_scores WHERE result_id=?', [$rid]);

        } else {

            DB::execute('INSERT INTO evaluation_results(umkm_id,period_id,score_composite,score_on_5,health_category,respondent_count,status,calculated_at,published_at) VALUES(?,?,?,?,?,? ,"published",NOW(),NOW())', [$umkmId,$periodId,$composite,$score5,$category,count($employees)+1]);

            $rid = (int)$pdo->lastInsertId();

        }

        foreach ($scores as $factor=>$value) {

            $n = in_array($factor,['INS','OPS','ECT'],true) ? 1 : count($employees);

            DB::execute('INSERT INTO result_factor_scores(result_id,factor_key,factor_score,respondent_count) VALUES(?,?,?,?)', [$rid,$factor,round($value,4),$n]);

        }

        // Preserve the official period status; aggregation must not reopen a lock.

        DB::execute("UPDATE evaluation_periods SET completed_at=NOW() WHERE id=?", [$periodId]);

        $pdo->commit();

    } catch (Throwable $e) { if ($pdo->inTransaction()) $pdo->rollBack(); throw $e; }

    return ['result_id'=>$rid,'scores'=>$scores,'composite'=>['composite'=>$composite,'scoreOn5'=>$score5,'category'=>$category],

        'score_composite'=>$composite,'score_on_5'=>$score5,'health_category'=>$category,'respondent_count'=>count($employees)+1,'employee_count'=>count($employees)];

}



$action = (string)($_GET['action'] ?? '');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {

    // Public list for the existing registration form. Registration itself is protected by invitation code.

    if ($action==='umkm_options' && $method==='GET') {

        $q = '%' . trim((string)($_GET['q']??'')) . '%';

        $rows = DB::fetchAll('SELECT id,name AS umkm_name FROM umkms WHERE is_active=1 AND name LIKE ? ORDER BY name LIMIT 200', [$q]);

        apiOut(true,$rows,'Daftar UMKM.');

    }



    if ($action==='register' && $method==='POST') {

        $b=apiInput(); $role=(string)($b['role']??'owner'); $email=strtolower(trim((string)($b['email']??'')));

        $password=(string)($b['password']??''); $name=trim((string)($b['umkm_name']??''));

        if (!filter_var($email,FILTER_VALIDATE_EMAIL) || strlen($password)<8) apiOut(false,null,'Email tidak valid atau password minimal 8 karakter.',422);

        if (DB::fetchOne('SELECT id FROM users WHERE email=?',[$email])) apiOut(false,null,'Email sudah terdaftar.',409);

        if (!in_array($role,['owner','employee'],true)) apiOut(false,null,'Role registrasi tidak valid.',422);

        $pdo=DB::pdo(); $pdo->beginTransaction();

        try {

            if ($role==='owner') {

                if (mb_strlen($name)<2) apiOut(false,null,'Nama UMKM minimal 2 karakter.',422);

                if (DB::fetchOne('SELECT id FROM umkms WHERE LOWER(TRIM(name))=LOWER(TRIM(?))',[$name])) apiOut(false,null,'UMKM sudah terdaftar.',409);

                DB::execute('INSERT INTO users(umkm_name,email,password_hash,role,lokasi,sektor,omzet,is_active) VALUES(?,?,?,"owner",?,?,?,1)',[$name,$email,password_hash($password,PASSWORD_DEFAULT),trim((string)($b['lokasi']??''))?:null,trim((string)($b['sektor']??''))?:null,is_numeric($b['omzet']??null)?(int)$b['omzet']:null]);

                $uid=(int)$pdo->lastInsertId();

                DB::execute('INSERT INTO umkms(owner_user_id,name,lokasi,sektor,omzet) VALUES(?,?,?,?,?)',[$uid,$name,trim((string)($b['lokasi']??''))?:null,trim((string)($b['sektor']??''))?:null,is_numeric($b['omzet']??null)?(int)$b['omzet']:null]);

                $mid=(int)$pdo->lastInsertId(); DB::execute('UPDATE users SET umkm_id=? WHERE id=?',[$mid,$uid]);

                // Initial period belongs to the authorized Owner-registration POST.
                DB::execute("INSERT INTO evaluation_periods(umkm_id,period_name,status,min_employee_responses,started_at,created_by) VALUES(?,?,'open',1,NOW(),?)",[$mid,'Evaluasi '.date('F Y'),$uid]);

            } else {

                $code=strtoupper(trim((string)($b['invitation_code']??'')));

                if ($code==='') apiOut(false,null,'Kode undangan dari Owner wajib diisi.',422);

                $invite=DB::fetchOne('SELECT * FROM invitation_codes WHERE code_hash=? AND is_active=1 AND expires_at>NOW() AND used_count<1 FOR UPDATE',[hash('sha256',$code)]);

                if (!$invite) apiOut(false,null,'Kode undangan tidak valid, kedaluwarsa, sudah digunakan, atau dicabut.',422);

                $invitedEmail=strtolower(trim((string)($invite['invited_email']??'')));

                if ($invitedEmail==='' || !hash_equals($invitedEmail,$email)) apiOut(false,null,'Email pendaftaran harus sama dengan email penerima undangan.',422);

                $umkm=DB::fetchOne('SELECT * FROM umkms WHERE id=? AND is_active=1',[(int)$invite['umkm_id']]);

                if (!$umkm) apiOut(false,null,'UMKM tidak aktif.',422);

                $name=$umkm['name'];

                DB::execute('INSERT INTO users(umkm_id,umkm_name,email,password_hash,role,lokasi,sektor,omzet,is_active) VALUES(?,?,?,?,"employee",?,?,?,1)',[(int)$umkm['id'],$name,$email,password_hash($password,PASSWORD_DEFAULT),$umkm['lokasi'],$umkm['sektor'],$umkm['omzet']]);

                $uid=(int)$pdo->lastInsertId(); $mid=(int)$umkm['id'];

                DB::execute('UPDATE invitation_codes SET used_count=used_count+1 WHERE id=?',[(int)$invite['id']]);

                DB::execute('INSERT INTO invitation_uses(invitation_id,user_id) VALUES(?,?)',[(int)$invite['id'],$uid]);

            }

            $pdo->commit();

            $token=makeToken($uid);

            apiOut(true,['token'=>$token,'user_id'=>$uid,'umkm_id'=>$mid,'role'=>$role,'email'=>$email,'umkm_name'=>$name,'lokasi'=>$b['lokasi']??'','sektor'=>$b['sektor']??'','omzet'=>$b['omzet']??null],'Registrasi berhasil.');

        } catch (Throwable $e) { if($pdo->inTransaction())$pdo->rollBack(); throw $e; }

    }



    if ($action==='login' && $method==='POST') {

        $b=apiInput(); $email=strtolower(trim((string)($b['email']??''))); $u=DB::fetchOne('SELECT * FROM users WHERE email=?',[$email]);

        if (!$u || !password_verify((string)($b['password']??''),(string)$u['password_hash'])) apiOut(false,null,'Email atau kata sandi salah.',401);

        if (!(int)$u['is_active']) apiOut(false,null,'Akun tidak aktif. Hubungi administrator.',403);

        // Role dari database adalah sumber kebenaran. Pilihan role pada form login
        // hanya untuk tampilan dan tidak boleh menolak kredensial yang valid.
        // Hak akses endpoint tetap diperiksa melalui currentUser()/needOwner().
        $actualRole = (string)$u['role'];
        $selectedRole = trim((string)($b['role'] ?? ''));
        $roleAliases = [
            'pemilik' => 'owner',
            'pemilik_usaha' => 'owner',
            'pemilik usaha' => 'owner',
            'pegawai' => 'employee',
            'karyawan' => 'employee',
            'admin' => 'platform_admin',
        ];
        $selectedRoleNormalized = strtolower($selectedRole);
        $selectedRoleNormalized = $roleAliases[$selectedRoleNormalized] ?? $selectedRoleNormalized;

        apiOut(true,[
            'token' => makeToken((int)$u['id']),
            'user_id' => (int)$u['id'],
            'umkm_id' => !empty($u['umkm_id']) ? (int)$u['umkm_id'] : null,
            'role' => $actualRole,
            'selected_role' => $selectedRoleNormalized !== '' ? $selectedRoleNormalized : null,
            'role_match' => $selectedRoleNormalized === '' || $selectedRoleNormalized === $actualRole,
            'email' => $u['email'],
            'umkm_name' => $u['umkm_name'],
            'lokasi' => $u['lokasi'] ?? '',
            'sektor' => $u['sektor'] ?? '',
            'omzet' => $u['omzet'] ?? null
        ],'Login berhasil. Role akun: '.$actualRole.'.');

    }



    if ($action==='me' && $method==='GET') { $u=currentUser(); apiOut(true,$u,'Profil berhasil diambil.'); }





function invitationEncryptCode(string $code): string {

    if (!function_exists('openssl_encrypt')) throw new RuntimeException('OpenSSL tidak tersedia untuk enkripsi kode undangan.');

    $key = hash('sha256', (string)JWT_SECRET . '|koyoumkm-invitation-code-v1', true);

    $nonce = random_bytes(12); $tag = '';

    $cipher = openssl_encrypt($code, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $nonce, $tag);

    if ($cipher === false) throw new RuntimeException('Kode undangan gagal dienkripsi.');

    return rtrim(strtr(base64_encode($nonce . $tag . $cipher), '+/', '-_'), '=');

}

function invitationDecryptCode(?string $encoded): ?string {

    if (!$encoded || !function_exists('openssl_decrypt')) return null;

    $raw = base64_decode(strtr($encoded, '-_', '+/'));

    if ($raw === false || strlen($raw) < 29) return null;

    $nonce = substr($raw, 0, 12); $tag = substr($raw, 12, 16); $cipher = substr($raw, 28);

    $key = hash('sha256', (string)JWT_SECRET . '|koyoumkm-invitation-code-v1', true);

    $plain = openssl_decrypt($cipher, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $nonce, $tag);

    return $plain === false ? null : $plain;

}



    if ($action==='set_employee_status' && $method==='POST') {
        $u=currentUser();
        if ($u['role']!=='owner') apiOut(false,null,'Akses hanya untuk Owner.',403);
        $b=apiInput();
        $targetId=filter_var($b['user_id']??null,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
        $active=$b['is_active']??null;
        if ($targetId===false || !in_array($active,[true,false,0,1,'0','1'],true)) apiOut(false,null,'ID pegawai atau status tidak valid.',422);
        if (!DB::fetchOne('SELECT id FROM umkms WHERE id=? AND owner_user_id=?',[(int)$u['umkm_id'],(int)$u['id']])) apiOut(false,null,'Akses UMKM ditolak.',403);
        $employee=DB::fetchOne('SELECT id FROM users WHERE id=? AND umkm_id=? AND role="employee"',[(int)$targetId,(int)$u['umkm_id']]);
        if (!$employee) apiOut(false,null,'Pegawai tidak ditemukan.',404);
        // Access status changes do not delete answers or rewrite historical results.
        $value=(int)(bool)$active;
        DB::execute('UPDATE users SET is_active=? WHERE id=? AND umkm_id=? AND role="employee"',[$value,(int)$targetId,(int)$u['umkm_id']]);
        apiOut(true,['user_id'=>(int)$targetId,'is_active'=>$value],'Status pegawai berhasil diperbarui.');
    }

    if ($action==='create_invitation' && $method==='POST') {

        $u=currentUser(); needOwner($u); $b=apiInput();

        $email=strtolower(trim((string)($b['invited_email']??'')));

        if (!filter_var($email,FILTER_VALIDATE_EMAIL)) apiOut(false,null,'Masukkan email pegawai yang valid.',422);

        if (DB::fetchOne('SELECT id FROM users WHERE email=?',[$email])) apiOut(false,null,'Email tersebut sudah memiliki akun VISTRA.',409);

        $pending=DB::fetchOne('SELECT id FROM invitation_codes WHERE umkm_id=? AND invited_email=? AND is_active=1 AND used_count=0 AND expires_at>NOW() LIMIT 1',[(int)$u['umkm_id'],$email]);

        if ($pending) apiOut(false,null,'Masih ada undangan aktif untuk email tersebut. Cabut undangan lama sebelum membuat yang baru.',409);

        $raw='KOYO-'.strtoupper(bin2hex(random_bytes(4))); $days=max(1,min(30,(int)($b['valid_days']??7)));

        DB::execute('INSERT INTO invitation_codes(umkm_id,owner_id,invited_email,code_hash,code_encrypted,max_uses,expires_at) VALUES(?,?,?,?,?,1,DATE_ADD(NOW(),INTERVAL ? DAY))',[(int)$u['umkm_id'],(int)$u['id'],$email,hash('sha256',$raw),invitationEncryptCode($raw),$days]);

        apiOut(true,['invitation_code'=>$raw,'invited_email'=>$email,'expires_in_days'=>$days,'max_uses'=>1],'Undangan personal berhasil dibuat. Kode hanya dapat digunakan oleh email penerima dan satu kali.');

    }



    if ($action==='my_invitations' && $method==='GET') {

        $u=currentUser(); needOwner($u);

        $rows=DB::fetchAll('SELECT id,invited_email,used_count,max_uses,expires_at,is_active,created_at,CASE WHEN used_count>=1 THEN "used" WHEN is_active=0 THEN "revoked" WHEN expires_at<=NOW() THEN "expired" ELSE "pending" END AS invitation_status FROM invitation_codes WHERE umkm_id=? ORDER BY id DESC LIMIT 100',[(int)$u['umkm_id']]);

        apiOut(true,$rows,'Riwayat undangan berhasil diambil.');

    }





    if ($action==='reveal_invitation_code' && $method==='POST') {

        $u=currentUser(); needOwner($u); $b=apiInput(); $id=(int)($b['invitation_id']??0);

        if ($id<1) apiOut(false,null,'ID undangan tidak valid.',422);

        $row=DB::fetchOne('SELECT id,invited_email,code_encrypted,used_count,max_uses,is_active,expires_at FROM invitation_codes WHERE id=? AND umkm_id=? AND owner_id=?',[$id,(int)$u['umkm_id'],(int)$u['id']]);

        if (!$row) apiOut(false,null,'Undangan tidak ditemukan.',404);

        if (!(int)$row['is_active'] || (int)$row['used_count'] >= (int)$row['max_uses'] || strtotime((string)$row['expires_at']) <= time()) apiOut(false,null,'Kode hanya dapat ditampilkan untuk undangan yang masih aktif dan belum digunakan.',409);

        $code=invitationDecryptCode($row['code_encrypted']??null);

        if (!$code) apiOut(false,null,'Kode undangan tidak dapat dipulihkan. Undangan ini dibuat sebelum fitur pemulihan kode. Cabut dan buat undangan baru.',409);

        apiOut(true,['invitation_id'=>$id,'invited_email'=>$row['invited_email'],'invitation_code'=>$code,'expires_at'=>$row['expires_at']],'Kode undangan berhasil dipulihkan.');

    }



    if ($action==='revoke_invitation' && $method==='POST') {

        $u=currentUser(); needOwner($u); $b=apiInput(); $id=(int)($b['invitation_id']??0);

        if ($id<1) apiOut(false,null,'ID undangan tidak valid.',422);

        $invite=DB::fetchOne('SELECT id,used_count FROM invitation_codes WHERE id=? AND umkm_id=? FOR UPDATE',[$id,(int)$u['umkm_id']]);

        if (!$invite) apiOut(false,null,'Undangan tidak ditemukan.',404);

        if ((int)$invite['used_count']>0) apiOut(false,null,'Undangan yang sudah digunakan tidak dapat dicabut.',409);

        DB::execute('UPDATE invitation_codes SET is_active=0 WHERE id=? AND umkm_id=?',[$id,(int)$u['umkm_id']]);

        apiOut(true,['invitation_id'=>$id],'Undangan berhasil dicabut.');

    }



    if ($action==='create_period' && $method==='POST') {

        $u=currentUser(); needOwner($u); $b=apiInput(); $name=trim((string)($b['period_name']??''));

        if (!$name) apiOut(false,null,'Nama periode wajib diisi.',422);

        $duplicate=DB::fetchOne('SELECT id FROM evaluation_periods WHERE umkm_id=? AND period_name=?',[(int)$u['umkm_id'],$name]);
        if($duplicate) apiOut(false,null,'Nama periode tersebut sudah digunakan. Gunakan nama periode yang berbeda.',409);
        $pdo=DB::pdo(); $pdo->beginTransaction();
        try {
            DB::execute("UPDATE evaluation_periods SET status='closed' WHERE umkm_id=? AND status IN ('open','published')",[(int)$u['umkm_id']]);
            DB::execute("INSERT INTO evaluation_periods(umkm_id,period_name,status,min_employee_responses,started_at,created_by) VALUES(?,?,'open',?,NOW(),?)",[(int)$u['umkm_id'],$name,max(1,min(50,(int)($b['min_employee_responses']??1))),(int)$u['id']]);
            $newPeriodId=(int)$pdo->lastInsertId();
            $pdo->commit();
        } catch(Throwable $e) { if($pdo->inTransaction()) $pdo->rollBack(); throw $e; }

        apiOut(true,['period_id'=>$newPeriodId],'Periode baru berhasil dibuat. Periode sebelumnya dikunci dan riwayatnya tetap tersimpan.');

    }

    if ($action==='periods' && $method==='GET') {

        $u=currentUser();

        $rows=$u['role']==='platform_admin' ? DB::fetchAll('SELECT p.*,m.name AS umkm_name FROM evaluation_periods p JOIN umkms m ON m.id=p.umkm_id ORDER BY p.id DESC') : DB::fetchAll('SELECT * FROM evaluation_periods WHERE umkm_id=? ORDER BY id DESC',[(int)$u['umkm_id']]);

        apiOut(true,$rows,'Daftar periode.');

    }


    // Riwayat periode dan hasil evaluasi khusus UMKM milik akun.
    if ($action==='period_history' && $method==='GET') {
        $u=currentUser();
        if (!in_array($u['role'],['owner','employee'],true)) apiOut(false,null,'Akses ditolak.',403);
        $umkmId=(int)$u['umkm_id'];
        $rows=DB::fetchAll(
            "SELECT p.id AS period_id,p.period_name,p.status AS period_status,p.started_at,p.created_at,
                    r.id AS result_id,r.score_on_5,r.health_category,r.respondent_count,r.status AS result_status,
                    r.calculated_at,r.published_at,
                    (SELECT COUNT(*) FROM submissions s WHERE s.period_id=p.id AND s.validation_pass=1) AS valid_submissions
             FROM evaluation_periods p
             LEFT JOIN evaluation_results r ON r.period_id=p.id AND r.umkm_id=p.umkm_id
             WHERE p.umkm_id=? ORDER BY p.id DESC",
            [$umkmId]
        );
        foreach ($rows as &$row) {
            $row['period_id']=(int)$row['period_id'];
            $row['valid_submissions']=(int)$row['valid_submissions'];
            $row['score_on_5']=$row['score_on_5']===null?null:(float)$row['score_on_5'];
            $row['factor_scores']=[];
            if (!empty($row['result_id'])) {
                $factors=DB::fetchAll(
                    'SELECT factor_key,factor_score,respondent_count FROM result_factor_scores WHERE result_id=?',
                    [(int)$row['result_id']]
                );
                foreach($factors as $factor) {
                    $row['factor_scores'][strtoupper((string)$factor['factor_key'])]=[
                        'score_on_5'=>round((float)$factor['factor_score']*5,2),
                        'respondent_count'=>(int)$factor['respondent_count']
                    ];
                }
            }
        }
        unset($row);
        apiOut(true,$rows,'Riwayat evaluasi berhasil diambil.');
    }

    // Mengunci periode agar tidak menerima submission baru. Data historis tetap tersimpan.
    if ($action==='close_period' && $method==='POST') {
        $u=currentUser(); needOwner($u); $b=apiInput();
        $periodId=(int)($b['period_id']??0);
        if ($periodId<1) apiOut(false,null,'ID periode tidak valid.',422);
        $period=DB::fetchOne('SELECT id,status FROM evaluation_periods WHERE id=? AND umkm_id=?',[$periodId,(int)$u['umkm_id']]);
        if (!$period) apiOut(false,null,'Periode tidak ditemukan.',404);
        if ($period['status']==='closed') apiOut(true,['period_id'=>$periodId,'status'=>'closed'],'Periode sudah dikunci.');
        DB::execute("UPDATE evaluation_periods SET status='closed' WHERE id=? AND umkm_id=?",[$periodId,(int)$u['umkm_id']]);
        apiOut(true,['period_id'=>$periodId,'status'=>'closed'],'Periode berhasil dikunci. Riwayat evaluasi tetap tersimpan.');
    }



    if ($action==='submit' && $method==='POST') {

        $u=currentUser(); if(!in_array($u['role'],['owner','employee'],true)) apiOut(false,null,'Role tidak dapat mengisi evaluasi.',403);

        $b=apiInput(); $period = !empty($b['period_id']) ? DB::fetchOne('SELECT * FROM evaluation_periods WHERE id=? AND umkm_id=?',[(int)$b['period_id'],(int)$u['umkm_id']]) : currentEvaluationPeriod((int)$u['umkm_id']);

        if (!$period || !in_array($period['status'],['open','published'],true)) apiOut(false,null,'Periode evaluasi tidak tersedia atau sudah ditutup.',409);

        $pid=(int)$period['id'];

        if(DB::fetchOne('SELECT id FROM submissions WHERE period_id=? AND user_id=?',[$pid,(int)$u['id']])) apiOut(false,null,'Anda sudah mengirim evaluasi pada periode ini.',409);

        $validated=Validator::validateSubmission(array_merge($b,['role'=>$u['role'],'email'=>$u['email'],'umkm_name'=>$u['umkm_name']]),$u['role']);

        if(!$validated['valid']) apiOut(false,['errors'=>$validated['errors'],'warnings'=>$validated['warnings']],'Jawaban belum valid.',422);

        $n8nResult=callN8nPredict(array_merge($b,['role'=>$u['role'],'email'=>$u['email'],'umkm_name'=>$u['umkm_name'],'period_id'=>$pid]));

        $s=$validated['scores']; $cols=['INS'=>null,'OV'=>null,'LDI'=>null,'WEQ'=>null,'OPS'=>null,'ECT'=>null];

        foreach($s as $f=>$v) $cols[$f]=(float)$v['normScore'];

        $pdo=DB::pdo(); $pdo->beginTransaction();

        try {

            // Serialize acceptance with an Owner locking this period concurrently.
            $lockedPeriod=DB::fetchOne('SELECT status FROM evaluation_periods WHERE id=? AND umkm_id=? FOR UPDATE',[$pid,(int)$u['umkm_id']]);
            if (!$lockedPeriod || !in_array($lockedPeriod['status'],['open','published'],true)) {
                $pdo->rollBack();
                apiOut(false,null,'Periode evaluasi tidak tersedia atau sudah ditutup.',409);
            }
            DB::execute('INSERT INTO submissions(period_id,user_id,role,status,validation_pass,submitted_at,validated_at,score_ins,score_ov,score_ldi,score_weq,score_ops,score_ect,score_composite,score_on_5,health_category) VALUES(?,?,?,"validated",1,NOW(),NOW(),?,?,?,?,?,?,?,?,?)',[$pid,(int)$u['id'],$u['role'],$cols['INS'],$cols['OV'],$cols['LDI'],$cols['WEQ'],$cols['OPS'],$cols['ECT'],null,null,null]);

            $sid=(int)$pdo->lastInsertId();

            foreach($validated['clean_data']['answers'] as $qid=>$value){

                $q=DB::fetchOne('SELECT factor_key,code,scale_max FROM question_definitions WHERE question_id=?',[$qid]);

                if(!$q) throw new RuntimeException('Pertanyaan tidak ditemukan: '.$qid);

                $factor=strtoupper((string)$q['factor_key']);

                DB::execute('INSERT INTO answers(submission_id,user_id,factor_key,question_id,question_code,answer_value,scale_max) VALUES(?,?,?,?,?,?,?)',[$sid,(int)$u['id'],$factor,$qid,$q['code'],$value,(int)$q['scale_max']]);

            }

            logWarnings($sid,$validated['warnings']); $pdo->commit();

        } catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();throw $e;}

        $result=calculatePeriodResult($pid,(int)$u['umkm_id']);

        $response=['submission_id'=>$sid,'period_id'=>$pid,'scores'=>$validated['scores'],'composite'=>$validated['composite'],'warnings'=>$validated['warnings'],'evaluation_status'=>$result?'published':'incomplete','n8n_status'=>$n8nResult['ok']?'connected':'fallback'];

        if($result){$response['evaluation_result']=$result;$response['composite']=$result['composite'];$response['scores']=array_merge($response['scores'],array_map(fn($v)=>['normScore'=>$v,'scoreOn5'=>round($v*5,2)],$result['scores']));}

        apiOut(true,$response,$result?'Evaluasi gabungan berhasil diperbarui.':'Jawaban tersimpan. Menunggu Owner dan minimal satu Employee.');

    }



    if ($action==='submission_status' && $method==='GET') {

        $u=currentUser(); $period=currentEvaluationPeriod((int)$u['umkm_id']);

        if (!in_array($u['role'], ['owner','employee'], true)) apiOut(false,null,'Role tidak dapat mengisi evaluasi.',403);
        $s=$period ? DB::fetchOne('SELECT id,status,submitted_at,period_id FROM submissions WHERE user_id=? AND period_id=? ORDER BY id DESC LIMIT 1',[(int)$u['id'],(int)$period['id']]) : null;
        $canSubmit=$period && in_array($period['status'],['open','published'],true) && !$s;
        apiOut(true,['has_submitted'=>(bool)$s,'submission'=>$s,'period'=>$period,'can_submit'=>(bool)$canSubmit],'Status evaluasi berhasil diambil.');

    }



    if ($action==='my_umkm' && $method==='GET') {

        $u=currentUser();

        $umkmId=(int)$u['umkm_id'];

        $m=DB::fetchOne('SELECT * FROM umkms WHERE id=?',[$umkmId]);



        // Periode evaluasi terbaru untuk UMKM ini.

        $period=DB::fetchOne("SELECT * FROM evaluation_periods WHERE umkm_id=? ORDER BY id DESC LIMIT 1",[$umkmId]);



        // Anggota dan status submit untuk periode aktif/terbaru.

        $members=DB::fetchAll(

            'SELECT id,email,role,is_active,created_at FROM users WHERE umkm_id=? ORDER BY FIELD(role,"owner","employee"),id',

            [$umkmId]

        );

        foreach($members as &$member) {

            $member['has_submitted']=false;
            $member['submission_id']=null;
            $member['submission_status']='not_submitted';
            $member['validation_pass']=0;
            if($period) {
                $submitted=DB::fetchOne(
                    'SELECT id,status,validation_pass,submitted_at,validated_at FROM submissions WHERE period_id=? AND user_id=? ORDER BY id DESC LIMIT 1',
                    [(int)$period['id'],(int)$member['id']]
                );
                if($submitted) {
                    $member['has_submitted']=true;
                    $member['submission_id']=(int)$submitted['id'];
                    $member['submission_status']=(string)$submitted['status'];
                    $member['validation_pass']=(int)$submitted['validation_pass'];
                    $member['submitted_at']=$submitted['submitted_at'];
                    $member['validated_at']=$submitted['validated_at'];
                }
            }
            $member['is_validated']=($member['submission_status']==='validated' && (int)$member['validation_pass']===1);
        }

        unset($member);



        $ownerSubmission=$period ? DB::fetchOne(
            "SELECT s.* FROM submissions s JOIN users u ON u.id=s.user_id WHERE s.period_id=? AND s.role='owner' AND u.umkm_id=? ORDER BY s.id DESC LIMIT 1",
            [(int)$period['id'],$umkmId]
        ) : null;
        $ownerHasSubmitted=false;
        $validatedEmployees=0;
        $submittedAccounts=0;
        $activeEmployees=0;
        foreach ($members as &$member) {
            $member['has_required_factors']=false;
            if ($period && $member['is_validated']) {
                $scores=DB::fetchOne('SELECT score_ins,score_ops,score_ect,score_ov,score_ldi,score_weq FROM submissions WHERE id=?',[(int)$member['submission_id']]);
                $keys=$member['role']==='owner' ? ['score_ins','score_ops','score_ect'] : ['score_ov','score_ldi','score_weq'];
                $member['has_required_factors']=$scores && count(array_filter($keys,fn($k)=>isset($scores[$k]) && is_numeric($scores[$k]) && (float)$scores[$k]>=0 && (float)$scores[$k]<=1))===3;
            }
            if ($member['role']==='employee' && (int)$member['is_active']===1) $activeEmployees++;
            if ((int)$member['is_active']!==1 || !$member['is_validated'] || !$member['has_required_factors']) continue;
            $submittedAccounts++;
            if ($member['role']==='owner') $ownerHasSubmitted=true;
            if ($member['role']==='employee') $validatedEmployees++;
        }
        unset($member);
        $requiredEmployees=$period ? max(1,(int)$period['min_employee_responses']) : 1;
        $completion=[
            'owner_submitted'=>$ownerHasSubmitted,
            'validated_employee_responses'=>$validatedEmployees,
            'required_employee_responses'=>$requiredEmployees,
            'submitted_accounts'=>$submittedAccounts,
            'active_accounts'=>$activeEmployees+1,
            'complete'=>$ownerHasSubmitted && $validatedEmployees >= $requiredEmployees
        ];
        $currentResult=$period ? DB::fetchOne('SELECT r.*,p.period_name FROM evaluation_results r JOIN evaluation_periods p ON p.id=r.period_id WHERE r.umkm_id=? AND r.period_id=?',[$umkmId,(int)$period['id']]) : null;
        $currentFactorScores=[];
        if ($currentResult) {
            foreach (DB::fetchAll('SELECT factor_key,factor_score,respondent_count FROM result_factor_scores WHERE result_id=?',[(int)$currentResult['id']]) as $factor) {
                $currentFactorScores[strtoupper($factor['factor_key'])]=['factor_score'=>(float)$factor['factor_score'],'respondent_count'=>(int)$factor['respondent_count']];
            }
        }

        $latestResult=DB::fetchOne(

            'SELECT r.*,p.period_name FROM evaluation_results r JOIN evaluation_periods p ON p.id=r.period_id WHERE r.umkm_id=? ORDER BY r.id DESC LIMIT 1',

            [$umkmId]

        );


        // Skor faktor Owner dan Employee yang telah diagregasi untuk hasil terbaru.
        $factorScores=[];
        if($latestResult) {
            $factorRows=DB::fetchAll(
                'SELECT factor_key,factor_score,respondent_count FROM result_factor_scores WHERE result_id=?',
                [(int)$latestResult['id']]
            );
            foreach($factorRows as $factorRow) {
                $factorKey=strtoupper((string)$factorRow['factor_key']);
                $factorScores[$factorKey]=[
                    'factor_score'=>(float)$factorRow['factor_score'],
                    'respondent_count'=>(int)$factorRow['respondent_count']
                ];
            }
        }
        apiOut(true,[

            'umkm'=>$m,

            'members'=>$members,

            'latest_result'=>$latestResult,
            'factor_scores'=>$factorScores,

            'current_period'=>$period,
            'current_result'=>$currentResult,
            'current_factor_scores'=>$currentFactorScores,
            'completion'=>$completion,

            'owner_submission'=>$ownerSubmission,

            'owner_has_submitted'=>$ownerHasSubmitted

        ],'Data UMKM berhasil diambil.');

    }

    if ($action==='my_result' && $method==='GET') {

        $u=currentUser(); $rows=DB::fetchAll('SELECT r.*,p.period_name FROM evaluation_results r JOIN evaluation_periods p ON p.id=r.period_id WHERE r.umkm_id=? ORDER BY r.id DESC',[(int)$u['umkm_id']]);

        apiOut(true,$rows,'Riwayat hasil evaluasi.');

    }



    if ($action==='dashboard' && $method==='GET') {

        $u=currentUser();

        if($u['role']==='platform_admin'){

            $stats=DB::fetchOne('SELECT (SELECT COUNT(*) FROM umkms) total_umkm,(SELECT COUNT(*) FROM umkms WHERE is_active=1) active_umkm,(SELECT COUNT(*) FROM users WHERE role="owner") total_owner,(SELECT COUNT(*) FROM users WHERE role="employee") total_employee,(SELECT COUNT(*) FROM users WHERE is_active=1 AND role IN ("owner","employee")) active_users,(SELECT COUNT(*) FROM evaluation_results) total_evaluations,(SELECT COUNT(*) FROM evaluation_periods) total_periods');

            $results=DB::fetchAll('SELECT r.*,m.name AS umkm_name,p.period_name FROM evaluation_results r JOIN umkms m ON m.id=r.umkm_id JOIN evaluation_periods p ON p.id=r.period_id ORDER BY r.id DESC LIMIT 100');

        }else{

            $stats=DB::fetchOne('SELECT 1 AS total_umkm,(SELECT COUNT(*) FROM users WHERE umkm_id=? AND role="employee" AND is_active=1) total_employee,(SELECT COUNT(*) FROM evaluation_results WHERE umkm_id=?) total_evaluations',[(int)$u['umkm_id'],(int)$u['umkm_id']]);

            $results=DB::fetchAll('SELECT r.*,p.period_name FROM evaluation_results r JOIN evaluation_periods p ON p.id=r.period_id WHERE r.umkm_id=? ORDER BY r.id DESC',[(int)$u['umkm_id']]);

        }

        apiOut(true,['stats'=>$stats,'results'=>$results],'Dashboard berhasil diambil.');

    }

    if ($action==='leaderboard' && $method==='GET') {

        $u=currentUser();



        $latestPeriod=DB::fetchOne(

            'SELECT p.period_name

             FROM evaluation_results r

             JOIN evaluation_periods p ON p.id=r.period_id

             WHERE r.status="published"

             ORDER BY COALESCE(r.published_at,r.calculated_at) DESC, r.id DESC

             LIMIT 1'

        );



        if (!$latestPeriod) {

            $unrated=DB::fetchAll(

                'SELECT id AS umkm_id, name AS umkm_name, lokasi, sektor,

                        NULL AS score_on_5, NULL AS health_category,

                        0 AS respondent_count, NULL AS calculated_at,

                        NULL AS period_name

                 FROM umkms

                 WHERE is_active=1

                 ORDER BY name ASC'

            );

            foreach ($unrated as &$row) {

                $row['rank']=null;

                $row['is_current_umkm']=(int)$row['umkm_id']===(int)$u['umkm_id'];

                $row['factor_scores']=[];

                $row['lowest_factor']=null;

                $row['lowest_factor_name']=null;

            }

            unset($row);

            apiOut(true,[

                'period_name'=>null,

                'rows'=>$unrated,

                'total'=>count($unrated),

                'ranked_total'=>0,

                'current_umkm_id'=>(int)$u['umkm_id'],

                'current_rank'=>null

            ],'Belum ada hasil evaluasi gabungan. Daftar UMKM aktif tetap ditampilkan.');

        }



        $periodName=(string)$latestPeriod['period_name'];

        $rows=DB::fetchAll(

            'SELECT r.id AS result_id, m.id AS umkm_id, m.name AS umkm_name,

                    m.lokasi, m.sektor, r.score_on_5, r.health_category,

                    r.respondent_count, r.calculated_at, p.period_name

             FROM umkms m

             LEFT JOIN (

                 SELECT r2.umkm_id, MAX(r2.id) AS latest_id

                 FROM evaluation_results r2

                 JOIN evaluation_periods p2 ON p2.id=r2.period_id

                 WHERE r2.status="published" AND p2.period_name=?

                 GROUP BY r2.umkm_id

             ) latest ON latest.umkm_id=m.id

             LEFT JOIN evaluation_results r ON r.id=latest.latest_id

             LEFT JOIN evaluation_periods p ON p.id=r.period_id

             WHERE m.is_active=1

             ORDER BY (r.score_on_5 IS NULL) ASC, r.score_on_5 DESC, m.name ASC',

            [$periodName]

        );



        $factorScores=[];

        if ($rows) {

            $resultIds=array_map(static fn($row)=>(int)$row['result_id'],$rows);

            $placeholders=implode(',',array_fill(0,count($resultIds),'?'));

            $factorRows=DB::fetchAll(

                'SELECT result_id,factor_key,factor_score

                 FROM result_factor_scores

                 WHERE result_id IN ('.$placeholders.')',

                $resultIds

            );

            foreach ($factorRows as $factorRow) {

                $rid=(int)$factorRow['result_id'];

                $factorScores[$rid][strtoupper((string)$factorRow['factor_key'])]=(float)$factorRow['factor_score'];

            }

        }



        $factorLabels=[

            'INS'=>'Sumber Daya Kelembagaan',

            'OV'=>'Nilai Organisasi',

            'LDI'=>'Keterlibatan Kepemimpinan',

            'WEQ'=>'Kualitas Lingkungan Kerja',

            'OPS'=>'Stabilitas Operasional',

            'ECT'=>'Konektivitas Ekonomi'

        ];

        $currentRank=null;

        $previousScore=null;

        $rankedCount=0;

        $rank=0;

        foreach ($rows as $index=>&$row) {

            $row['is_current_umkm']=(int)$row['umkm_id']===(int)$u['umkm_id'];

            if ($row['score_on_5']===null) {

                $row['rank']=null;

                $row['factor_scores']=[];

                $row['lowest_factor']=null;

                $row['lowest_factor_name']=null;

                $row['period_name']=$periodName;

                unset($row['result_id']);

                continue;

            }



            $score=(float)$row['score_on_5'];

            $rankedCount++;

            if ($previousScore===null || abs($score-$previousScore)>0.00001) {

                $rank=$rankedCount;

            }

            $row['rank']=$rank;

            if ($row['is_current_umkm']) $currentRank=$rank;

            $rid=(int)$row['result_id'];

            $scores=$factorScores[$rid]??[];

            $row['factor_scores']=$scores;

            $lowestKey=null;

            $lowestValue=null;

            foreach ($scores as $key=>$value) {

                if ($lowestValue===null || $value<$lowestValue) {

                    $lowestKey=$key;

                    $lowestValue=$value;

                }

            }

            $row['lowest_factor']=$lowestKey;

            $row['lowest_factor_name']=$lowestKey ? ($factorLabels[$lowestKey]??$lowestKey) : null;

            $previousScore=$score;

            unset($row['result_id']);

        }

        unset($row);



        apiOut(true,[

            'period_name'=>$periodName,

            'rows'=>$rows,

            'total'=>count($rows),

            'ranked_total'=>$rankedCount,

            'current_umkm_id'=>(int)$u['umkm_id'],

            'current_rank'=>$currentRank

        ],'Peringkat UMKM berhasil diambil.');

    }



    if ($action==='umkm_list' && $method==='GET') {

        $u=currentUser(); if($u['role']!=='platform_admin') apiOut(false,null,'Endpoint khusus Platform Admin.',403);

        $limit=max(1,min(100,(int)($_GET['limit']??15))); $offset=max(0,(int)($_GET['offset']??0)); $q='%'.trim((string)($_GET['search']??'' )).'%';

        $rows=DB::fetchAll('SELECT m.*,u.email AS owner_email FROM umkms m JOIN users u ON u.id=m.owner_user_id WHERE m.name LIKE ? ORDER BY m.id DESC LIMIT '.$limit.' OFFSET '.$offset,[$q]);

        $total=(int)(DB::fetchOne('SELECT COUNT(*) n FROM umkms WHERE name LIKE ?',[$q])['n']??0);

        apiOut(true,['rows'=>$rows,'total'=>$total],'Daftar UMKM.');

    }

    if ($action==='factor_averages' && $method==='GET') {

        $u=currentUser();

        $sql='SELECT f.factor_key,AVG(f.factor_score) AS avg_score FROM result_factor_scores f JOIN evaluation_results r ON r.id=f.result_id';

        $rows=$u['role']==='platform_admin'?DB::fetchAll($sql.' GROUP BY f.factor_key') : DB::fetchAll($sql.' WHERE r.umkm_id=? GROUP BY f.factor_key',[(int)$u['umkm_id']]);

        apiOut(true,$rows,'Rata-rata faktor berhasil diambil.');

    }

    apiOut(false,null,'Endpoint tidak ditemukan.',404);

} catch (Throwable $e) {

    vistraServerError($e);

}
