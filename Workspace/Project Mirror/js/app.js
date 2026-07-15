// Supabase Configuration
// TODO: Replace with your actual Supabase URL and Anon Key
const SUPABASE_URL = 'https://qlrraiaayeqdlfdopujz.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFscnJhaWFheWVxZGxmZG9wdWp6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1NTU4NDMsImV4cCI6MjA5OTEzMTg0M30.ku09G3A5I8YCSZKOMdzQYkxI95JAXyAw5IbKsQxQGik';

// Initialize Supabase Client (CDN)
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// State
let registry = [];
let currentUser = null;

// DOM Elements
const registryTableBody = document.getElementById('registryTableBody');
const registryCount = document.getElementById('registryCount');
const searchInput = document.getElementById('searchInput');
const authContainer = document.getElementById('authContainer');

// Modal Elements
const spawnModal = document.getElementById('spawnModal');
const spawnForm = document.getElementById('spawnForm');

// Initialize Application
async function init() {
    setupEventListeners();
    await checkAuth();
    await fetchProjects();
}

// Authentication Logic
async function checkAuth() {
    const { data: { session }, error } = await supabase.auth.getSession();
    currentUser = session?.user || null;
    renderAuthUI();
}

async function loginWithEmail(e) {
    e.preventDefault();
    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;
    
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    
    if (error) {
        console.error('Error logging in:', error.message);
        alert(`Login Failed: ${error.message}\n\n(If you don't have an account yet, click "Create Account")`);
    } else {
        document.getElementById('loginModal').classList.remove('active');
        currentUser = data.user;
        renderAuthUI();
    }
}

async function signUpWithEmail() {
    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;
    
    if (!email || !password) {
        alert("Please enter an email and password to create an account.");
        return;
    }

    const { data, error } = await supabase.auth.signUp({ email, password });
    
    if (error) {
        console.error('Error signing up:', error.message);
        alert(`Sign Up Failed: ${error.message}`);
    } else {
        alert("Account created successfully! Note: If you have 'Confirm Email' enabled in Supabase, you must check your email before signing in. Otherwise, you are good to go!");
        document.getElementById('loginModal').classList.remove('active');
        currentUser = data.user;
        renderAuthUI();
    }
}

async function logout() {
    const { error } = await supabase.auth.signOut();
    if (!error) {
        currentUser = null;
        renderAuthUI();
    }
}

function renderAuthUI() {
    if (currentUser) {
        authContainer.innerHTML = `
            <div style="display: flex; align-items: center; gap: 12px;">
                <div class="avatar" style="background-color: var(--accent-primary); display: flex; align-items: center; justify-content: center; font-weight: bold;">
                    ${currentUser.email.charAt(0).toUpperCase()}
                </div>
                <button class="btn btn-secondary" onclick="logout()">Sign Out</button>
            </div>
        `;
    } else {
        authContainer.innerHTML = `
            <button class="btn btn-secondary" id="loginBtn" onclick="document.getElementById('loginModal').classList.add('active')">Sign In</button>
        `;
    }
}

// Ensure the login form handles the submit event
document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('loginForm');
    if (loginForm) loginForm.addEventListener('submit', loginWithEmail);
});

// Database Logic (Registry)
async function fetchProjects() {
    // Show loading state
    registryTableBody.innerHTML = '<tr><td colspan="4" style="text-align: center; color: var(--text-muted);">Syncing with Supabase...</td></tr>';

    try {
        const { data, error } = await supabase
            .from('projects')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw error;

        registry = data || [];
        renderRegistry(registry);
    } catch (error) {
        console.error('Error fetching projects:', error.message);
        // Fallback mock data if Supabase isn't configured yet
        registry = [
            { id: 1, target_proprietary: 'Jira', open_source_alternative: 'Plane', status: 'Active (Mock)' },
            { id: 2, target_proprietary: 'Slack', open_source_alternative: 'Mattermost', status: 'Active (Mock)' }
        ];
        renderRegistry(registry);
    }
}

async function spawnCompetitor(target, name) {
    if (!currentUser) {
        alert("You must be signed in to spawn a competitor!");
        return;
    }

    try {
        const { data, error } = await supabase
            .from('projects')
            .insert([{ target_proprietary: target, open_source_alternative: name }])
            .select();

        if (error) throw error;

        // Add to local state and re-render
        if (data && data.length > 0) {
            registry.unshift(data[0]);
            renderRegistry(registry);
        }
    } catch (error) {
        console.error('Error inserting project:', error.message);
        alert('Failed to spawn competitor. Check console for details.');
    }
}

// Render the semantic table
function renderRegistry(projects) {
    registryTableBody.innerHTML = '';
    registryCount.innerText = `${projects.length} Active`;

    projects.forEach(proj => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td class="td-target">${proj.target_proprietary}</td>
            <td class="td-alternative">${proj.open_source_alternative}</td>
            <td>
                <div class="status-indicator">
                    <span class="status-dot"></span>
                    ${proj.status}
                </div>
            </td>
            <td>
                <button class="btn btn-secondary" onclick="joinProject('${proj.open_source_alternative}')">Join</button>
            </td>
        `;
        registryTableBody.appendChild(tr);
    });
}

// Event Listeners
function setupEventListeners() {
    searchInput.addEventListener('input', (e) => {
        const term = e.target.value.toLowerCase();
        const filtered = registry.filter(p =>
            p.target_proprietary.toLowerCase().includes(term) ||
            p.open_source_alternative.toLowerCase().includes(term)
        );
        renderRegistry(filtered);
    });

    // Close modal when clicking the 'x' button or the overlay background
    document.getElementById('cancelSpawn').addEventListener('click', closeSpawnModal);
    spawnModal.addEventListener('click', (e) => {
        if (e.target === spawnModal) closeSpawnModal();
    });

    spawnForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const target = document.getElementById('targetProprietary').value;
        const name = document.getElementById('newName').value;

        closeSpawnModal();
        await spawnCompetitor(target, name);
        spawnForm.reset();
    });
}

// Action Handlers
function joinProject(name) {
    if (!currentUser) {
        alert(`Authentication required to join ${name}. Please sign in first.`);
        return;
    }
    alert(`Connecting to ${name} repository architecture...`);
}

function openSpawnModal() {
    spawnModal.classList.add('active');
}

function closeSpawnModal() {
    spawnModal.classList.remove('active');
}

// Boot
init();
