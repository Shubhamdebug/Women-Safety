
// ==========================================
// WOMEN SAFETY ANALYTICS DASHBOARD
// ==========================================

// DEMO DATA
// These records are fictional sample data.
// Replace them with Flask API data later.

const incidents = [

    {
        id: "WS001",
        type: "Harassment",
        location: "Central Area",
        date: "2026-11-10",
        priority: "High",
        status: "Pending",
        latitude: 12.9716,
        longitude: 77.5946
    },

    {
        id: "WS002",
        type: "Stalking",
        location: "North Area",
        date: "2026-11-09",
        priority: "Medium",
        status: "Resolved",
        latitude: 13.0358,
        longitude: 77.5970
    },

    {
        id: "WS003",
        type: "Emergency",
        location: "South Area",
        date: "2026-11-08",
        priority: "High",
        status: "Pending",
        latitude: 12.9166,
        longitude: 77.6101
    },

    {
        id: "WS004",
        type: "Harassment",
        location: "East Area",
        date: "2026-11-07",
        priority: "Medium",
        status: "Under Review",
        latitude: 12.9698,
        longitude: 77.7499
    },

    {
        id: "WS005",
        type: "Unsafe Location",
        location: "West Area",
        date: "2026-11-06",
        priority: "Low",
        status: "Resolved",
        latitude: 12.9900,
        longitude: 77.5400
    },

    {
        id: "WS006",
        type: "Emergency",
        location: "Central Area",
        date: "2026-11-05",
        priority: "High",
        status: "Pending",
        latitude: 12.9600,
        longitude: 77.5800
    },

    {
        id: "WS007",
        type: "Stalking",
        location: "North Area",
        date: "2026-11-04",
        priority: "Low",
        status: "Resolved",
        latitude: 13.0200,
        longitude: 77.6000
    }

];


// ==========================================
// 1. UPDATE CURRENT DATE
// ==========================================

const dateElement = document.getElementById("currentDate");

dateElement.textContent = new Date().toLocaleDateString(
    "en-IN",
    {
        day: "numeric",
        month: "short",
        year: "numeric"
    }
);


// ==========================================
// 2. UPDATE DASHBOARD STATISTICS
// ==========================================

function updateStatistics() {

    const total = incidents.length;

    const resolved = incidents.filter(
        incident => incident.status === "Resolved"
    ).length;

    const pending = incidents.filter(
        incident => incident.status === "Pending"
    ).length;

    const emergency = incidents.filter(
        incident => incident.type === "Emergency"
    ).length;

    document.getElementById("totalIncidents").textContent = total;

    document.getElementById("resolvedCases").textContent = resolved;

    document.getElementById("pendingReports").textContent = pending;

    document.getElementById("emergencyAlerts").textContent = emergency;
}


// ==========================================
// 3. DISPLAY INCIDENT REPORTS
// ==========================================

function displayReports(data) {

    const table = document.getElementById("reportTable");

    table.innerHTML = "";

    if (data.length === 0) {

        table.innerHTML = `
            <tr>
                <td colspan="6" class="empty-message">
                    No matching reports found.
                </td>
            </tr>
        `;

    } else {

        data.forEach(incident => {

            const row = document.createElement("tr");

            const statusClass = incident.status.replace(" ", "-");

            row.innerHTML = `
                <td><strong>${incident.id}</strong></td>
                <td>${incident.type}</td>
                <td>${incident.location}</td>
                <td>${incident.date}</td>

                <td>
                    <span class="priority ${incident.priority}">
                        ${incident.priority}
                    </span>
                </td>

                <td>
                    <span class="status ${statusClass}">
                        ${incident.status}
                    </span>
                </td>
            `;

            table.appendChild(row);

        });

    }

    document.getElementById("reportCount").textContent =
        `Showing ${data.length} of ${incidents.length} reports`;

}


// ==========================================
// 4. SEARCH AND FILTER REPORTS
// ==========================================

const searchInput = document.getElementById("searchInput");

const statusFilter = document.getElementById("statusFilter");


function filterReports() {

    const searchValue = searchInput.value.toLowerCase();

    const selectedStatus = statusFilter.value;

    const filteredData = incidents.filter(incident => {

        const matchesSearch =
            incident.id.toLowerCase().includes(searchValue) ||
            incident.type.toLowerCase().includes(searchValue) ||
            incident.location.toLowerCase().includes(searchValue);

        const matchesStatus =
            selectedStatus === "All" ||
            incident.status === selectedStatus;

        return matchesSearch && matchesStatus;

    });

    displayReports(filteredData);

}


searchInput.addEventListener("input", filterReports);

statusFilter.addEventListener("change", filterReports);


// ==========================================
// 5. MONTHLY INCIDENT TREND CHART
// ==========================================

const trendCanvas = document.getElementById("trendChart");

new Chart(trendCanvas, {

    type: "line",

    data: {

        labels: [
            "Jan", "Feb", "Mar", "Apr",
            "May", "Jun", "Jul", "Aug",
            "Sep", "Oct", "Nov", "Dec"
        ],

        datasets: [{

            label: "Incidents",

            data: [12, 19, 14, 25, 18, 30, 22, 35, 28, 40, 32, 20],

            borderColor: "#7955c8",

            backgroundColor: "rgba(121, 85, 200, 0.12)",

            fill: true,

            tension: 0.4,

            borderWidth: 3,

            pointRadius: 4,

            pointBackgroundColor: "#7955c8"

        }]

    },

    options: {

        responsive: true,

        maintainAspectRatio: false,

        plugins: {
            legend: {
                display: false
            }
        },

        scales: {

            y: {
                beginAtZero: true,
                ticks: {
                    precision: 0
                }
            }

        }

    }

});


// ==========================================
// 6. INCIDENT CATEGORY PIE CHART
// ==========================================

const categoryCounts = {};

incidents.forEach(incident => {

    categoryCounts[incident.type] =
        (categoryCounts[incident.type] || 0) + 1;

});


new Chart(document.getElementById("categoryChart"), {

    type: "doughnut",

    data: {

        labels: Object.keys(categoryCounts),

        datasets: [{

            data: Object.values(categoryCounts),

            backgroundColor: [
                "#7955c8",
                "#f2a65a",
                "#e65c70",
                "#4cae8a"
            ],

            borderWidth: 2,

            borderColor: "#ffffff"

        }]

    },

    options: {

        responsive: true,

        maintainAspectRatio: false,

        plugins: {

            legend: {
                position: "bottom"
            }

        }

    }

});


// ==========================================
// 7. LEAFLET SAFETY MAP
// ==========================================

const map = L.map("safetyMap").setView(
    [12.9716, 77.5946],
    11
);


// Map tiles

L.tileLayer(
    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
    {
        attribution: "&copy; OpenStreetMap contributors"
    }
).addTo(map);


// Add incident markers

incidents.forEach(incident => {

    const marker = L.marker([
        incident.latitude,
        incident.longitude
    ]).addTo(map);

    marker.bindPopup(`
        <strong>Report ID:</strong> ${incident.id}<br>
        <strong>Type:</strong> ${incident.type}<br>
        <strong>Location:</strong> ${incident.location}<br>
        <strong>Priority:</strong> ${incident.priority}<br>
        <strong>Status:</strong> ${incident.status}
    `);

});


// ==========================================
// 8. EMERGENCY ALERTS
// ==========================================

function displayAlerts() {

    const alertsContainer = document.getElementById("alertsList");

    const emergencyIncidents = incidents.filter(
        incident =>
            incident.type === "Emergency" &&
            incident.status !== "Resolved"
    );

    alertsContainer.innerHTML = "";

    if (emergencyIncidents.length === 0) {

        alertsContainer.innerHTML = `
            <div class="card empty-message">
                No active emergency alerts.
            </div>
        `;

        return;
    }

    emergencyIncidents.forEach(incident => {

        const alert = document.createElement("div");

        alert.className = "alert-item";

        alert.innerHTML = `

            <div>
                <h3>⚠ Emergency Report: ${incident.id}</h3>

                <p>
                    Location: ${incident.location}
                    | Date: ${incident.date}
                </p>
            </div>

            <span class="alert-tag">
                ${incident.status}
            </span>

        `;

        alertsContainer.appendChild(alert);

    });

}


// ==========================================
// 9. EXPORT REPORTS TO CSV
// ==========================================

document.getElementById("exportBtn").addEventListener(
    "click",
    function () {

        const headers = [
            "Report ID",
            "Incident Type",
            "Location",
            "Date",
            "Priority",
            "Status"
        ];

        const rows = incidents.map(incident => [

            incident.id,
            incident.type,
            incident.location,
            incident.date,
            incident.priority,
            incident.status

        ]);

        const csvContent = [
            headers,
            ...rows
        ].map(row =>
            row.map(value =>
                `"${String(value).replace(/"/g, '""')}"`
            ).join(",")
        ).join("\n");

        const blob = new Blob(
            ["\uFEFF" + csvContent],
            { type: "text/csv;charset=utf-8;" }
        );

        const url = URL.createObjectURL(blob);

        const link = document.createElement("a");

        link.href = url;

        link.download = "women_safety_reports.csv";

        link.click();

        URL.revokeObjectURL(url);

    }
);


// ==========================================
// 10. NOTIFICATION BUTTON
// ==========================================

document.getElementById("notificationBtn").addEventListener(
    "click",
    function () {

        const activeAlerts = incidents.filter(
            incident =>
                incident.type === "Emergency" &&
                incident.status !== "Resolved"
        ).length;

        alert(
            `You have ${activeAlerts} active emergency alerts in the demo data.`
        );

    }
);


// ==========================================
// 11. SIDEBAR NAVIGATION
// ==========================================

const navigationLinks = document.querySelectorAll(".nav-link");

navigationLinks.forEach(link => {

    link.addEventListener("click", function () {

        navigationLinks.forEach(item =>
            item.classList.remove("active")
        );

        this.classList.add("active");

    });

});


// ==========================================
// 12. INITIALIZE DASHBOARD
// ==========================================

updateStatistics();

displayReports(incidents);

displayAlerts();

console.log("SafeHer Dashboard Loaded Successfully!");
