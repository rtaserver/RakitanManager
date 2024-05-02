const app = new Vue({
    el: '#app',
    data() {
        return {
            status: false,
            connection: 0,
            log: "",
            wan_ip: "",
            wan_country: "",
            wan_isp: "",
        }
    },
    methods: {
        getSystemConfig() {
            return new Promise((resolve) => {
                axios.post('api.php', {
                    action: "get_system_config"
                }).then((res) => {
                    resolve(res.data.data)
                })
            })
        },
        getWanIp() {
            return new Promise((resolve) => {
                axios.get('http://ip-api.com/json?fields=query,country,isp').then((res) => {
                    this.wan_ip = res.data.query
                    this.wan_country = "(" + res.data.country + ")"
                    this.wan_isp = res.data.isp
                    resolve(res)
                })
            })
        },
        intervalGetWanIp() {
            setInterval(() => {
                this.getWanIp()
            }, 5000)
        },
        getDashboardInfo() {
            return new Promise((resolve) => {
                axios.post('api.php', {
                    action: "get_dashboard_info"
                }).then((res) => {
                    resolve(res)
                })
            })
        },
        intervalGetDashboardInfo() {
            setInterval(() => {
                this.getDashboardInfo()
            }, 1000)
        },
    },
    created() {
        this.getSystemConfig().then((res) => {
            const mode = res.tunnel.mode
            this.config.system = res
            this.config.mode = mode
            this.getProfiles(mode)
        })
        this.getDashboardInfo().then(() => {
            this.$refs.log.scrollTop = this.$refs.log.scrollHeight
            this.intervalGetDashboardInfo()
        }).catch(() => {
            this.$refs.log.scrollTop = this.$refs.log.scrollHeight
            this.intervalGetDashboardInfo()
        })
        this.getWanIp().then(() => this.intervalGetWanIp()).catch(() => this.intervalGetWanIp())
    }
})