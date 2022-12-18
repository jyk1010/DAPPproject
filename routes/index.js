const express = require('express')
const router = express.Router();
// const web3interface = require('../public/javascripts/web3interface')

let public_key;

/* GET home page. */
router.get('/', function(req, res) {
 	res.render('index', { address: req.cookies.public_key });
});

router.post('/', function(req, res) {
	public_key = req.body.public_key;
	console.log(public_key);
	res.cookie('public_key', public_key);
	res.redirect('/');
});

router.post('/registerUser', function(req, res) {
	console.log(req.body);
	web3.registerUser(req.body.name);
	res.redirect('/');
});

module.exports = router;
