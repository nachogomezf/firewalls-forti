from fpdf import FPDF
import json

class PDF(FPDF):
    def __init__(self, nombre, ip, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.nombre = nombre
        self.ip = ip

    def header(self):
        self.set_font('Helvetica', 'B', 10)  # Usar Helvetica en lugar de Arial
        self.cell(0, 10, f'Reporte de políticas {self.nombre} {self.ip}', 0, new_x="LMARGIN", new_y="NEXT", align='C')
        self.ln(10)

    def chapter_title(self, title):
        self.set_font('Helvetica', 'B', 10)  # Usar Helvetica en lugar de Arial
        self.cell(0, 10, title, 0, new_x="LMARGIN", new_y="NEXT", align='L')
        self.ln(5)

    def add_table(self, title, policies):
        self.add_page()
        self.chapter_title(title)
        
        if not policies:
            self.cell(0, 10, 'No data available', 0, new_x="LMARGIN", new_y="NEXT", align='L')
            return

        # Definir encabezados de columna y anchuras
        headers = ["VDOM", "srcint", "dstint", "SRC", "DST", "SVC", "ACTION"]
        col_widths = [20, 35, 35, 60, 60, 35, 20]

        # Establecer fuente para encabezados
        self.set_font('Helvetica', 'B', 10)  # Usar Helvetica en lugar de Arial
        for i, header in enumerate(headers):
            self.cell(col_widths[i], 8, header, 1, new_x="RIGHT", new_y="TOP", align='C')  # Altura de fila reducida
        self.ln()

        # Establecer fuente para filas
        self.set_font('Helvetica', '', 8)  # Usar Helvetica en lugar de Arial
        row_height = 8  # Altura de fila reducida
        for i, policy in enumerate(policies):
            if self.get_y() + row_height > self.page_break_trigger:
                self.add_page()
                self.chapter_title(title)
                self.set_font('Helvetica', 'B', 10)  # Usar Helvetica en lugar de Arial
                for i, header in enumerate(headers):
                    self.cell(col_widths[i], 8, header, 1, new_x="RIGHT", new_y="TOP", align='C')  # Altura de fila reducida
                self.ln()
                self.set_font('Helvetica', '', 8)  # Usar Helvetica en lugar de Arial
                
            # Establecer color de relleno para filas alternas
            fill = i % 2 == 0
            if fill:
                self.set_fill_color(230, 230, 230)  # gris claro

            max_y = self.get_y()
            for j, key in enumerate(["VDOM", "srcint", "dstint", "SRC", "DST", "SVC", "ACTION"]):
                # Usar multi_cell para contenido potencialmente largo
                x_before = self.get_x()
                y_before = self.get_y()
                self.multi_cell(col_widths[j], row_height, policy.get(key, ""), border=1, align='L', fill=fill)
                max_y = max(max_y, self.get_y())
                self.set_xy(x_before + col_widths[j], y_before)
            
            self.set_y(max_y)

def read_file(filename):
    with open(filename, 'r') as file:
        data = json.load(file)
    return data

def info_firewall(address):
    firewall_info_interfaces = read_file(address)
    firewall_info_interfaces = firewall_info_interfaces["FWS"]
    nombre_firewall = firewall_info_interfaces[0]["nombre"]
    IP_firewall = firewall_info_interfaces[0]["IP"]

    return nombre_firewall, IP_firewall

def create_pdf_from_json(json_data, pdf_filename, nombre, ip):
    pdf = PDF(nombre, ip, orientation='L')
    pdf.add_table('Políticas Añadidas', json_data.get("politicas", {}).get("add", []))
    pdf.add_table('Políticas Eliminadas', json_data.get("politicas", {}).get("delete", []))
    pdf.output(pdf_filename)

if __name__ == "__main__":
    json_data = read_file("data/output/comparation_v2.json")
    nombre, ip = info_firewall("references/config_FWs.json")
    create_pdf_from_json(json_data, "data/output/reporte.pdf", nombre, ip)
