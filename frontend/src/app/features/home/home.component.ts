import { Component } from '@angular/core';

type ServiceLink = {
  title: string;
  description: string;
  route: string;
};

@Component({
  selector: 'app-home',
  standalone: true,
  templateUrl: './home.component.html',
  styleUrl: './home.component.scss'
})
export class HomeComponent {
  protected readonly serviceLinks: ServiceLink[] = [
    {
      title: 'Carta de servicos',
      description: 'Consulte canais, documentos e prazos para atendimento.',
      route: '/servicos'
    },
    {
      title: 'Transparencia',
      description: 'Acompanhe receitas, despesas, licitacoes e contratos.',
      route: '/transparencia'
    },
    {
      title: 'Ouvidoria',
      description: 'Registre manifestacoes e acompanhe respostas oficiais.',
      route: '/ouvidoria'
    },
    {
      title: 'Diario oficial',
      description: 'Acesse publicacoes oficiais e edicoes anteriores.',
      route: '/diario-oficial'
    }
  ];
}
